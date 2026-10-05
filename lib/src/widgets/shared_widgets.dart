part of '../screens.dart';

class _NearbyProvidersPreview extends StatelessWidget {
  const _NearbyProvidersPreview();

  @override
  Widget build(BuildContext context) {
    if (!signedIn) {
      return const InlineMessage(
        icon: Icons.login_outlined,
        text: 'Sign in to see available providers near you.',
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AuthService().watchOnlineProviders(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const InlineMessage(
            icon: Icons.cloud_off_outlined,
            text: 'Unable to load online providers.',
          );
        }
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final providers = snapshot.data!.docs.take(2).toList();
        if (providers.isEmpty) {
          return const InlineMessage(
            icon: Icons.person_search_outlined,
            text: 'No service providers are online right now.',
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < providers.length; index++) ...[
              if (index > 0) const SizedBox(width: RaSpace.sm),
              Expanded(
                child: _OnlineProviderPreviewCard(
                  data: providers[index].data(),
                ),
              ),
            ],
            if (providers.length == 1) const Spacer(),
          ],
        );
      },
    );
  }
}

class _DriverQuickAction extends StatelessWidget {
  const _DriverQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF182733)
        : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(RaRadius.md),
      side: BorderSide(color: Theme.of(context).dividerColor),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RaSpace.sm,
          vertical: RaSpace.md,
        ),
        child: Column(
          children: [
            IconBadge(icon, size: 38),
            const SizedBox(height: RaSpace.sm),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RaText.label.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OnlineProviderPreviewCard extends StatelessWidget {
  const _OnlineProviderPreviewCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final name = data['displayName'] as String? ?? 'Service Provider';
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => push(context, const AssistanceTypeScreen()),
        child: Padding(
          padding: const EdgeInsets.all(RaSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProfileInitials(name: name, radius: 24),
                  const Spacer(),
                  const StatusPill(label: 'Online', tone: RaTone.success),
                ],
              ),
              const SizedBox(height: RaSpace.md),
              Text(
                name,
                style: RaText.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Available for roadside requests',
                style: RaText.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InlineMessage extends StatelessWidget {
  const InlineMessage({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(RaSpace.lg),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(RaRadius.md),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Row(
      children: [
        IconBadge(icon, size: 38),
        const SizedBox(width: RaSpace.md),
        Expanded(
          child: Text(
            text,
            style: RaText.bodyMuted.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DriverEmergencyContactTile extends StatelessWidget {
  const _DriverEmergencyContactTile();

  @override
  Widget build(BuildContext context) {
    if (!signedIn) {
      return ContactTile(
        'Family Contact',
        'Sign in to configure',
        onTap: () => push(context, const EmergencyScreen()),
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: AuthService().watchCurrentProfile(),
      builder: (context, snapshot) {
        final contact =
            snapshot.data?.data()?['emergencyContact'] as String? ?? '';
        final configured = contact.trim().isNotEmpty && contact != 'Not added';
        return ContactTile(
          'Family Contact',
          configured ? contact : 'Tap to add contact',
          onTap: () => push(context, const EmergencyScreen()),
        );
      },
    );
  }
}

class _DriverRequestPreview extends StatelessWidget {
  const _DriverRequestPreview({required this.request});
  final QueryDocumentSnapshot<Map<String, dynamic>> request;

  @override
  Widget build(BuildContext context) {
    final data = request.data();
    final status = data['status'] as String? ?? 'searching';
    final label = switch (status) {
      'searching' => 'Searching',
      'accepted' => 'Accepted',
      'en_route' => 'En route',
      'arrived' => 'Provider arrived',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => status.replaceAll('_', ' '),
    };
    final tone = status == 'completed'
        ? RaTone.success
        : status == 'cancelled'
        ? RaTone.danger
        : RaTone.info;
    final draft = requestDraftFromData(data);
    void resumeRequest() {
      if (status == 'searching') {
        push(context, SearchingScreen(draft: draft, requestId: request.id));
      } else if (const ['accepted', 'en_route', 'arrived'].contains(status)) {
        push(context, TrackingScreen(draft: draft, requestId: request.id));
      } else {
        push(
          context,
          RealtimeDriverRequestDetailsScreen(requestId: request.id, data: data),
        );
      }
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(RaRadius.lg),
        onTap: resumeRequest,
        child: Padding(
          padding: const EdgeInsets.all(RaSpace.lg),
          child: Row(
            children: [
              const IconBadge(Icons.car_repair_outlined, size: 44),
              const SizedBox(width: RaSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(requestIssueLabel(data), style: RaText.title),
                    const SizedBox(height: 6),
                    StatusPill(label: label, tone: tone),
                  ],
                ),
              ),
              Column(
                children: [
                  const Icon(Icons.chevron_right_rounded, color: raMuted),
                  const SizedBox(height: 4),
                  Text(
                    const [
                          'searching',
                          'accepted',
                          'en_route',
                          'arrived',
                        ].contains(status)
                        ? 'Resume'
                        : 'Details',
                    style: RaText.caption.copyWith(
                      color: raBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoSourceTile extends StatelessWidget {
  const _PhotoSourceTile({
    required this.icon,
    required this.label,
    this.description = '',
    required this.source,
  });
  final IconData icon;
  final String label;
  final String description;
  final ImageSource source;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: IconBadge(icon),
    title: Text(label, style: RaText.title),
    subtitle: description.isEmpty ? null : Text(description),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.pop(context, source),
  );
}

class _LocationAccuracyIndicator extends StatelessWidget {
  const _LocationAccuracyIndicator({
    required this.accuracyMeters,
    required this.onRefresh,
  });

  final double? accuracyMeters;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final accuracy = accuracyMeters;
    final (label, color, icon) = accuracy == null
        ? ('Manual pin - refresh GPS', raMuted, Icons.gps_not_fixed)
        : accuracy <= 8
        ? (
            'High accuracy - +/-${accuracy.ceil()} m',
            raSuccess,
            Icons.gps_fixed,
          )
        : accuracy <= 35
        ? (
            'Medium accuracy - +/-${accuracy.ceil()} m',
            raGold,
            Icons.gps_not_fixed,
          )
        : ('Low accuracy - refresh location', raDanger, Icons.gps_off_rounded);
    return InkWell(
      onTap: accuracy == null || accuracy > 35 ? onRefresh : null,
      borderRadius: BorderRadius.circular(RaRadius.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: RaSpace.sm,
          vertical: RaSpace.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(RaRadius.sm),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: RaSpace.sm),
            Expanded(
              child: Text(
                label,
                style: RaText.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (accuracy == null || accuracy > 35)
              Icon(Icons.refresh, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}

class _NearbyProvidersMap extends StatelessWidget {
  const _NearbyProvidersMap({
    required this.draft,
    required this.selectedId,
    required this.providers,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> providers;
  final RequestDraft draft;
  final String? selectedId;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: providers,
        builder: (context, snapshot) {
          final providerDocuments = snapshot.data?.docs;
          final providers = providerDocuments == null
              ? <QueryDocumentSnapshot<Map<String, dynamic>>>[]
              : providerDocuments
                    .where(
                      (provider) =>
                          _providerMatchesDraft(provider.data(), draft),
                    )
                    .toList();
          final positions = <LatLng>[];
          LatLng? selectedPosition;
          for (final provider in providers) {
            final data = provider.data();
            final latitude = (data['latitude'] as num?)?.toDouble();
            final longitude = (data['longitude'] as num?)?.toDouble();
            if (latitude == null || longitude == null) continue;
            final point = LatLng(latitude, longitude);
            positions.add(point);
            if (provider.id == selectedId) selectedPosition = point;
          }
          return MapMock(
            position: LatLng(draft.latitude, draft.longitude),
            providerPositions: positions,
            selectedProviderPosition: selectedPosition,
          );
        },
      );
}

class _RequestValidationChecklist extends StatelessWidget {
  const _RequestValidationChecklist({required this.draft});

  final RequestDraft draft;

  @override
  Widget build(BuildContext context) {
    final checks = <(String, bool, bool)>[
      (
        'Vehicle details added',
        draft.modelYear.isNotEmpty && draft.registration.isNotEmpty,
        true,
      ),
      ('Breakdown description added', draft.description.isNotEmpty, false),
      (
        'Location confirmed',
        !draft.location.startsWith('Select current GPS'),
        true,
      ),
      (
        'Preferred provider (optional)',
        draft.preferredProviderId.isNotEmpty,
        false,
      ),
      ('Photo evidence added', draft.vehiclePhotoUrls.isNotEmpty, false),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(RaSpace.lg),
        child: Column(
          children: checks.map((check) {
            final (label, complete, required) = check;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    complete
                        ? Icons.check_circle_rounded
                        : required
                        ? Icons.error_outline_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: complete
                        ? raSuccess
                        : required
                        ? raDanger
                        : raMuted,
                    size: 20,
                  ),
                  const SizedBox(width: RaSpace.sm),
                  Expanded(child: Text(label, style: RaText.body)),
                  if (!required) const Text('Optional', style: RaText.caption),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _DriverHistoryCard extends StatelessWidget {
  const _DriverHistoryCard({required this.requestId, required this.data});
  final String requestId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'searching';
    final active = const [
      'searching',
      'accepted',
      'en_route',
      'arrived',
    ].contains(status);
    final draft = requestDraftFromData(data);

    void continueRequest() {
      if (status == 'searching') {
        push(context, SearchingScreen(draft: draft, requestId: requestId));
      } else {
        push(context, TrackingScreen(draft: draft, requestId: requestId));
      }
    }

    Future<void> cancelActiveRequest() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: raDanger),
          title: const Text('Cancel current request?'),
          content: const Text(
            'The active assistance request will be stopped and moved to Cancelled history.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep Request'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: raDanger),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Cancel Request'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      try {
        await RequestService().cancelRequest(requestId);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assistance request cancelled.')),
        );
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to cancel this request.')),
        );
      }
    }

    final statusLabel = switch (status) {
      'searching' => 'Searching',
      'accepted' => 'Accepted',
      'en_route' => 'En route',
      'arrived' => 'Arrived',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => status.replaceAll('_', ' '),
    };
    final tone = status == 'completed'
        ? RaTone.success
        : status == 'cancelled'
        ? RaTone.danger
        : RaTone.info;
    final provider =
        data['providerName'] as String? ??
        (status == 'searching' ? 'Finding a provider' : 'Not assigned');
    final vehicle = [
      data['vehicleType'] as String? ?? '',
      data['modelYear'] as String? ?? '',
      data['registration'] as String? ?? '',
    ].where((value) => value.trim().isNotEmpty).join(' - ');
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final dateLabel = createdAt == null
        ? 'Date unavailable'
        : '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}  ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(RaSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateLabel.toUpperCase(), style: RaText.eyebrow),
            const SizedBox(height: RaSpace.sm),
            Row(
              children: [
                const IconBadge(Icons.car_repair_outlined, size: 38),
                const SizedBox(width: RaSpace.sm),
                Expanded(
                  child: Text(
                    data['issue'] as String? ?? 'Roadside assistance',
                    style: RaText.title,
                  ),
                ),
                StatusPill(label: statusLabel, tone: tone),
              ],
            ),
            const Divider(height: RaSpace.xxl),
            SummaryRow('Provider', provider),
            SummaryRow('Vehicle', vehicle.isEmpty ? 'Not provided' : vehicle),
            SummaryRow(
              'Location',
              data['locationLabel'] as String? ?? 'Pinned location',
            ),
            SummaryRow(
              status == 'completed' ? 'Total Cost' : 'Estimated Cost',
              'Rs. ${data['finalCost'] ?? data['estimatedCost'] ?? 0}',
              strong: true,
            ),
            if (data['driverRating'] != null)
              SummaryRow('Your Rating', '${data['driverRating']} / 5 stars'),
            const SizedBox(height: RaSpace.sm),
            if (active) ...[
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: continueRequest,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Continue'),
                    ),
                  ),
                  const SizedBox(width: RaSpace.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: cancelActiveRequest,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: raDanger,
                        side: const BorderSide(color: raDanger),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 17),
                      label: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RaSpace.sm),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => push(
                  context,
                  RealtimeDriverRequestDetailsScreen(
                    requestId: requestId,
                    data: data,
                  ),
                ),
                icon: const Icon(Icons.receipt_long_outlined, size: 17),
                label: const Text('View Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(
      children: [
        Icon(icon, color: raMuted, size: 17),
        const SizedBox(width: RaSpace.sm),
        Expanded(child: Text(label, style: RaText.caption)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: RaText.label,
          ),
        ),
      ],
    ),
  );
}

class _ProviderRealtimeStats extends StatelessWidget {
  const _ProviderRealtimeStats({required this.services});

  final List<String> services;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: RequestService().watchOpenRequests(),
        builder: (context, openSnapshot) =>
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: RequestService().watchProviderRequests(),
              builder: (context, assignedSnapshot) {
                final userId = FirebaseAuth.instance.currentUser?.uid;
                final newCount =
                    openSnapshot.data?.docs.where((request) {
                      return userId != null &&
                          _requestMatchesProvider(
                            request.data(),
                            userId,
                            services: services,
                          );
                    }).length ??
                    0;
                final assigned = assignedSnapshot.data?.docs ?? const [];
                final activeCount = assigned.where((request) {
                  return const [
                    'accepted',
                    'en_route',
                    'arrived',
                  ].contains(request.data()['status']);
                }).length;
                final completedCount = assigned
                    .where((request) => request.data()['status'] == 'completed')
                    .length;
                return Row(
                  children: [
                    Expanded(
                      child: ProviderStat(
                        value: newCount.toString().padLeft(2, '0'),
                        label: 'New requests',
                        icon: Icons.mark_email_unread_outlined,
                      ),
                    ),
                    const SizedBox(width: RaSpace.sm),
                    Expanded(
                      child: ProviderStat(
                        value: activeCount.toString().padLeft(2, '0'),
                        label: 'Active jobs',
                        icon: Icons.build_circle_outlined,
                      ),
                    ),
                    const SizedBox(width: RaSpace.sm),
                    Expanded(
                      child: ProviderStat(
                        value: completedCount.toString().padLeft(2, '0'),
                        label: 'Completed',
                        icon: Icons.verified_outlined,
                      ),
                    ),
                  ],
                );
              },
            ),
      );
}

class _ProviderPresenceAvatar extends StatelessWidget {
  const _ProviderPresenceAvatar({required this.name, required this.online});

  final String name;
  final bool online;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      ProfileInitials(
        name: name,
        foregroundColor: Colors.white,
        background: Colors.white24,
      ),
      Positioned(
        right: -2,
        bottom: -2,
        child: Tooltip(
          message: online ? 'Active now' : 'Offline',
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: online ? raSuccess : raMuted,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _ProviderRequestBadge extends StatelessWidget {
  const _ProviderRequestBadge({required this.services});
  final List<String> services;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: signedIn ? RequestService().watchOpenRequests() : null,
        builder: (context, snapshot) {
          final userId = FirebaseAuth.instance.currentUser?.uid;
          final count =
              snapshot.data?.docs.where((request) {
                final data = request.data();
                return userId != null &&
                    _requestMatchesProvider(data, userId, services: services);
              }).length ??
              0;
          return Badge(
            isLabelVisible: count > 0,
            backgroundColor: raDanger,
            label: Text(count > 9 ? '9+' : '$count'),
            child: IconButton(
              tooltip: 'New requests',
              onPressed: () =>
                  push(context, const ProviderNotificationsScreen()),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          );
        },
      );
}

class _ProviderActiveJobsSection extends StatelessWidget {
  const _ProviderActiveJobsSection();

  @override
  Widget build(BuildContext context) {
    if (!signedIn) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: RequestService().watchProviderRequests(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.hasError) {
          return const SizedBox.shrink();
        }
        final activeJobs = snapshot.data!.docs.where((request) {
          return const [
            'accepted',
            'en_route',
            'arrived',
          ].contains(request.data()['status']);
        }).toList();
        if (activeJobs.isEmpty) return const SizedBox.shrink();
        final job = activeJobs.first;
        final data = job.data();
        final driver = data['driverName'] as String? ?? 'Driver';
        final status = (data['status'] as String? ?? 'accepted').replaceAll(
          '_',
          ' ',
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle('Active Job'),
            const SizedBox(height: RaSpace.md),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(RaRadius.lg),
                onTap: () => push(
                  context,
                  ProviderActiveJobScreen(requestId: job.id, requestData: data),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(RaSpace.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ProfileInitials(name: driver, radius: 22),
                          const SizedBox(width: RaSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(driver, style: RaText.title),
                                Text(
                                  data['issue'] as String? ??
                                      'Roadside assistance',
                                  style: RaText.caption,
                                ),
                              ],
                            ),
                          ),
                          StatusPill(label: status, tone: RaTone.info),
                        ],
                      ),
                      const SizedBox(height: RaSpace.md),
                      Text(
                        data['locationLabel'] as String? ?? 'Pinned location',
                        style: RaText.bodyMuted,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: RaSpace.md),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => push(
                            context,
                            ProviderActiveJobScreen(
                              requestId: job.id,
                              requestData: data,
                            ),
                          ),
                          icon: const Icon(Icons.navigation_outlined),
                          label: const Text('Resume Active Job'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: RaSpace.xxl),
          ],
        );
      },
    );
  }
}

class _ProviderServicesOverview extends StatelessWidget {
  const _ProviderServicesOverview({
    required this.services,
    required this.serviceRadius,
    required this.onManage,
  });

  final List<String> services;
  final String serviceRadius;
  final VoidCallback onManage;

  IconData iconFor(String service) => switch (service) {
    'Vehicle Towing' => Icons.fire_truck_outlined,
    'Battery Jumpstart' => Icons.battery_charging_full,
    'Flat Tyre' => Icons.tire_repair_outlined,
    'General Mechanic' => Icons.car_repair_outlined,
    _ => Icons.home_repair_service_outlined,
  };

  String detailFor(String service) => switch (service) {
    'Vehicle Towing' => 'Recovery and transport',
    'Battery Jumpstart' => 'Battery and power recovery',
    'Flat Tyre' => 'Tyre repair and replacement',
    'General Mechanic' => 'Diagnostics and roadside repair',
    _ => 'Roadside assistance service',
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionTitle('Registered Services', action: 'Manage', onAction: onManage),
      const SizedBox(height: RaSpace.xs),
      Text('Coverage: $serviceRadius', style: RaText.caption),
      const SizedBox(height: RaSpace.md),
      if (services.isEmpty)
        Card(
          color: Theme.of(context).colorScheme.surface,
          child: ListTile(
            leading: const IconBadge(Icons.add_business_outlined),
            title: const Text('Add your services', style: RaText.title),
            subtitle: const Text(
              'Choose services to receive matching requests.',
              style: RaText.caption,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onManage,
          ),
        )
      else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: services.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: RaSpace.sm,
            mainAxisSpacing: RaSpace.sm,
            childAspectRatio: 1.55,
          ),
          itemBuilder: (context, index) {
            final service = services[index];
            return Card(
              color: Theme.of(context).colorScheme.surface,
              child: InkWell(
                borderRadius: BorderRadius.circular(RaRadius.lg),
                onTap: onManage,
                child: Padding(
                  padding: const EdgeInsets.all(RaSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconBadge(iconFor(service), size: 34, iconSize: 18),
                      const Spacer(),
                      Text(
                        service,
                        style: RaText.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detailFor(service),
                        style: RaText.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
    ],
  );
}

class _ProviderNewRequestsBanner extends StatelessWidget {
  const _ProviderNewRequestsBanner({required this.services});

  final List<String> services;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: signedIn ? RequestService().watchOpenRequests() : null,
        builder: (context, snapshot) {
          final userId = FirebaseAuth.instance.currentUser?.uid;
          final count =
              snapshot.data?.docs.where((request) {
                return userId != null &&
                    _requestMatchesProvider(
                      request.data(),
                      userId,
                      services: services,
                    );
              }).length ??
              0;
          return FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: count > 0 ? const Color(0xFFF09500) : raBlue,
              minimumSize: const Size.fromHeight(58),
            ),
            onPressed: () => push(context, const ProviderNotificationsScreen()),
            icon: Icon(
              count > 0
                  ? Icons.notifications_active_outlined
                  : Icons.inbox_outlined,
            ),
            label: Text(
              count > 0
                  ? 'View $count New ${count == 1 ? 'Request' : 'Requests'}'
                  : 'View Assistance Requests',
            ),
          );
        },
      );
}

class _ProviderRatingSummary extends StatelessWidget {
  const _ProviderRatingSummary();

  @override
  Widget build(BuildContext context) {
    if (!signedIn) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: RequestService().watchProviderRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const InlineMessage(
            icon: Icons.star_outline_rounded,
            text: 'Unable to load driver ratings.',
          );
        }
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final ratings = snapshot.data!.docs
            .map((request) => request.data()['driverRating'])
            .whereType<num>()
            .map((rating) => rating.toDouble())
            .toList();
        if (ratings.isEmpty) {
          return const InlineMessage(
            icon: Icons.star_outline_rounded,
            text: 'No ratings yet. Completed job ratings will appear here.',
          );
        }
        final average = ratings.reduce((a, b) => a + b) / ratings.length;
        final fiveStarCount = ratings.where((rating) => rating == 5).length;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(RaSpace.lg),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: raGoldPale,
                    borderRadius: BorderRadius.circular(RaRadius.md),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: raGold,
                    size: 36,
                  ),
                ),
                const SizedBox(width: RaSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        average.toStringAsFixed(1),
                        style: RaText.numeric.copyWith(fontSize: 26),
                      ),
                      Text(
                        '${ratings.length} driver ${ratings.length == 1 ? 'review' : 'reviews'}',
                        style: RaText.bodyMuted,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$fiveStarCount', style: RaText.numeric),
                    const Text('5-star', style: RaText.caption),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UnreadChatIcon extends StatelessWidget {
  const _UnreadChatIcon({required this.requestId, required this.seenField});

  final String? requestId;
  final String seenField;

  @override
  Widget build(BuildContext context) {
    if (requestId == null || !signedIn) {
      return const Icon(Icons.chat_outlined);
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: RequestService().watchRequest(requestId!),
      builder: (context, requestSnapshot) {
        final seenAt = requestSnapshot.data?.data()?[seenField] as Timestamp?;
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: RequestService().watchMessages(requestId!),
          builder: (context, messageSnapshot) {
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
            final unread =
                messageSnapshot.data?.docs.where((message) {
                  final data = message.data();
                  if (data['senderId'] == currentUserId) return false;
                  final createdAt = data['createdAt'] as Timestamp?;
                  return seenAt == null ||
                      createdAt == null ||
                      createdAt.compareTo(seenAt) > 0;
                }).length ??
                0;
            return Badge(
              isLabelVisible: unread > 0,
              backgroundColor: raDanger,
              label: Text(unread > 9 ? '9+' : '$unread'),
              child: const Icon(Icons.chat_outlined),
            );
          },
        );
      },
    );
  }
}

class StatusTimeline extends StatelessWidget {
  const StatusTimeline({
    super.key,
    required this.statuses,
    required this.current,
  });
  final List<String> statuses;
  final int current;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: List.generate(
      statuses.length,
      (index) => Expanded(
        child: Column(
          children: [
            Row(
              children: [
                if (index > 0)
                  Expanded(
                    child: Container(
                      height: 3,
                      color: index <= current ? raBlue : raLine,
                    ),
                  ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: index < current
                        ? raBlue
                        : index == current
                        ? Colors.white
                        : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: index <= current ? raBlue : raLine,
                      width: index == current ? 2.4 : 1.6,
                    ),
                  ),
                  child: index < current
                      ? const Icon(Icons.check, color: Colors.white, size: 15)
                      : index == current
                      ? const Center(
                          child: SizedBox(
                            width: 8,
                            height: 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: raBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
                if (index < statuses.length - 1)
                  Expanded(
                    child: Container(
                      height: 3,
                      color: index < current ? raBlue : raLine,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: RaSpace.sm),
            Text(
              statuses[index],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: index == current
                    ? FontWeight.w800
                    : FontWeight.w600,
                color: index <= current
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ProviderStat extends StatelessWidget {
  const ProviderStat({
    super.key,
    required this.value,
    required this.label,
    this.icon,
  });
  final String value;
  final String label;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(
        vertical: RaSpace.md,
        horizontal: RaSpace.sm,
      ),
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, color: raBlue, size: 18),
            const SizedBox(height: 6),
          ],
          Text(value, style: RaText.numeric),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: RaText.caption.copyWith(fontSize: 9.5),
          ),
        ],
      ),
    ),
  );
}

class DetailTimeline extends StatelessWidget {
  const DetailTimeline({super.key});

  @override
  Widget build(BuildContext context) {
    const entries = [
      ('Request submitted', '02:18 PM'),
      ('Provider accepted', '02:21 PM'),
      ('Provider arrived', '02:34 PM'),
      ('Service completed', '02:52 PM'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(RaSpace.lg),
        child: Column(
          children: List.generate(
            entries.length,
            (index) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: raSuccess,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                    if (index < entries.length - 1)
                      Container(width: 2, height: 32, color: raLine),
                  ],
                ),
                const SizedBox(width: RaSpace.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(entries[index].$1, style: RaText.label),
                  ),
                ),
                Text(entries[index].$2, style: RaText.caption),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProviderJobCard extends StatelessWidget {
  const ProviderJobCard({
    super.key,
    required this.driver,
    required this.vehicle,
    required this.service,
    required this.date,
    required this.location,
    required this.cost,
    required this.completed,
    required this.onViewDetails,
  });

  final String driver;
  final String vehicle;
  final String service;
  final String date;
  final String location;
  final String cost;
  final bool completed;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(RaSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProfileInitials(name: driver, radius: 20),
              const SizedBox(width: RaSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver, style: RaText.title),
                    Text(vehicle, style: RaText.caption),
                  ],
                ),
              ),
              Text(cost, style: RaText.numeric.copyWith(fontSize: 16)),
            ],
          ),
          const Divider(height: RaSpace.xxl),
          SummaryRow('Service', service),
          SummaryRow('Date & Time', date),
          SummaryRow('Location', location),
          const SizedBox(height: RaSpace.sm),
          Row(
            children: [
              StatusPill(
                label: completed ? 'Completed' : 'Cancelled',
                tone: completed ? RaTone.success : RaTone.danger,
              ),
              const Spacer(),
              TextButton(
                onPressed: onViewDetails,
                child: const Text('View Details'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class ProviderServiceTile extends StatelessWidget {
  const ProviderServiceTile({
    super.key,
    required this.icon,
    required this.title,
  });
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(RaSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon, size: 38),
          const SizedBox(height: RaSpace.sm),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                title,
                style: RaText.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      vertical: RaSpace.xxxl,
      horizontal: RaSpace.xl,
    ),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(RaRadius.md),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Column(
      children: [
        IconBadge(icon, size: 52, color: raMuted),
        const SizedBox(height: RaSpace.md),
        Text(title, style: RaText.title, textAlign: TextAlign.center),
        const SizedBox(height: RaSpace.xs),
        Text(message, textAlign: TextAlign.center, style: RaText.bodyMuted),
      ],
    ),
  );
}

// ============================================================
// SHARED — BRAND, LAYOUT & INPUT PRIMITIVES
// ============================================================

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.size, this.elevated = false});
  final double size;
  final bool elevated;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: raBlue,
      borderRadius: BorderRadius.circular(size * .26),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ]
          : null,
    ),
    child: Icon(Icons.shield_outlined, color: Colors.white, size: size * .55),
  );
}

class Dot extends StatelessWidget {
  const Dot({super.key, this.active = false, this.onDark = false});
  final bool active;
  final bool onDark;
  @override
  Widget build(BuildContext context) => Container(
    width: active ? 8 : 6,
    height: active ? 8 : 6,
    margin: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: active
          ? (onDark ? Colors.white : raBlue)
          : (onDark ? Colors.white24 : raLine),
      shape: BoxShape.circle,
    ),
  );
}

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(
      RaSpace.lg,
      RaSpace.md,
      RaSpace.lg,
      RaSpace.lg,
    ),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF397DBD), Color(0xFF4A90CF)],
      ),
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(RaRadius.lg),
      ),
    ),
    child: child,
  );
}

class AssetSlot extends StatelessWidget {
  const AssetSlot({
    super.key,
    required this.height,
    required this.label,
    required this.icon,
    this.assetPath,
  });
  final double height;
  final String label;
  final IconData icon;
  final String? assetPath;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    width: double.infinity,
    color: const Color(0xFFDCE8F2),
    child: Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: ScenicPainter()),
        if (assetPath != null)
          Image.asset(
            assetPath!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        if (assetPath == null)
          Center(
            child: Container(
              padding: const EdgeInsets.all(RaSpace.md),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .9),
                borderRadius: BorderRadius.circular(RaRadius.sm),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: raBlue, size: 34),
                  const SizedBox(height: RaSpace.xs),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: raNavy,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class ScenicPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFB7D9EC));
    final hill = Path()
      ..moveTo(0, s.height * .58)
      ..quadraticBezierTo(
        s.width * .28,
        s.height * .2,
        s.width * .54,
        s.height * .58,
      )
      ..quadraticBezierTo(s.width * .78, s.height * .32, s.width, s.height * .6)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    c.drawPath(hill, Paint()..color = const Color(0xFF568D72));
    final road = Path()
      ..moveTo(s.width * .42, s.height)
      ..quadraticBezierTo(
        s.width * .52,
        s.height * .66,
        s.width * .62,
        s.height * .49,
      )
      ..lineTo(s.width * .7, s.height * .51)
      ..quadraticBezierTo(s.width * .58, s.height * .7, s.width * .63, s.height)
      ..close();
    c.drawPath(road, Paint()..color = const Color(0xFF485467));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FeatureTile extends StatelessWidget {
  const FeatureTile(this.icon, this.title, this.body, {super.key});
  final IconData icon;
  final String title, body;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(RaSpace.md),
      child: Row(
        children: [
          IconBadge(icon),
          const SizedBox(width: RaSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: RaText.title),
                const SizedBox(height: 1),
                Text(body, style: RaText.caption),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class RoleOptionCard extends StatelessWidget {
  const RoleOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.badge,
    required this.description,
    required this.buttonLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String badge;
  final String description;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(RaSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(icon, size: 52, iconSize: 26),
              const SizedBox(width: RaSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge,
                      style: RaText.eyebrow.copyWith(
                        color: raBlue,
                        fontSize: 9.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(title, style: RaText.title.copyWith(fontSize: 17)),
                    const SizedBox(height: RaSpace.xs),
                    Text(description, style: RaText.bodyMuted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: RaSpace.lg),
          const Divider(height: 1),
          const SizedBox(height: RaSpace.md),
          FilledButton.icon(
            onPressed: onTap,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(buttonLabel),
          ),
        ],
      ),
    ),
  );
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: RaSpace.sm),
    child: Text(text, style: RaText.eyebrow),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(title, style: RaText.headline)),
      if (action != null)
        TextButton(
          onPressed: onAction,
          child: Text(
            action!,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: raBlue,
            ),
          ),
        ),
    ],
  );
}

class StepEyebrow extends StatelessWidget {
  const StepEyebrow({super.key, required this.step, required this.of});
  final int step;
  final int of;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 1; i <= of; i++) ...[
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: i <= step ? raBlue : raLine,
              borderRadius: BorderRadius.circular(RaRadius.pill),
            ),
          ),
        ),
        if (i != of) const SizedBox(width: RaSpace.xs),
      ],
    ],
  );
}

class ServicePreview extends StatelessWidget {
  const ServicePreview({
    super.key,
    required this.title,
    required this.detail,
    required this.icon,
    required this.assetPath,
  });
  final String title, detail;
  final IconData icon;
  final String assetPath;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(RaSpace.sm + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(RaRadius.sm),
            child: Image.asset(
              assetPath,
              height: 104,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 104,
                color: raPale,
                child: Icon(icon, color: raBlue, size: 36),
              ),
            ),
          ),
          const SizedBox(height: RaSpace.sm),
          Text(title, style: RaText.label),
          const SizedBox(height: 2),
          Text(detail, style: RaText.caption),
        ],
      ),
    ),
  );
}

class ContactTile extends StatelessWidget {
  const ContactTile(this.title, this.number, {super.key, required this.onTap});
  final String title, number;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(
      horizontal: RaSpace.md,
      vertical: 2,
    ),
    leading: const IconBadge(
      Icons.emergency_outlined,
      background: raDangerPale,
      color: raDanger,
      size: 38,
    ),
    title: Text(title, style: RaText.title),
    subtitle: Text(number, style: RaText.caption),
    trailing: IconButton(
      onPressed: onTap,
      icon: const Icon(Icons.call, size: 19),
    ),
  );
}

class SafetyBox extends StatelessWidget {
  const SafetyBox({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(RaSpace.md),
    decoration: BoxDecoration(
      color: raGoldPale,
      borderRadius: BorderRadius.circular(RaRadius.sm),
      border: Border.all(color: raGold.withValues(alpha: 0.35)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, color: raGold),
        SizedBox(width: RaSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SAFETY FIRST',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF8A5600),
                  letterSpacing: 0.6,
                ),
              ),
              Text(
                'Move your vehicle to the shoulder and turn on hazard lights if possible.',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8A5600),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class BottomAction extends StatelessWidget {
  const BottomAction({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(
      RaSpace.xl,
      RaSpace.sm,
      RaSpace.xl,
      RaSpace.xl,
    ),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(top: BorderSide(color: raLine)),
    ),
    child: FilledButton(onPressed: enabled ? onTap : null, child: Text(label)),
  );
}

class FormSectionTitle extends StatelessWidget {
  const FormSectionTitle(this.icon, this.title, {super.key});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconBadge(icon, size: 30, iconSize: 16),
      const SizedBox(width: RaSpace.sm),
      Text(title, style: RaText.title),
    ],
  );
}

// ============================================================
// SHARED — MAP
// ============================================================

class MapMock extends StatelessWidget {
  const MapMock({
    super.key,
    this.position,
    this.providerPosition,
    this.providerPositions = const [],
    this.selectedProviderPosition,
    this.onPositionSelected,
    this.showProviders = false,
    this.showRoute = false,
    this.routePoints,
  });

  final LatLng? position;
  final LatLng? providerPosition;
  final List<LatLng> providerPositions;
  final LatLng? selectedProviderPosition;
  final ValueChanged<LatLng>? onPositionSelected;
  final bool showProviders;
  final bool showRoute;
  final List<LatLng>? routePoints;

  static const breakdownPoint = LatLng(6.9034, 79.8525);
  static const providerPoint = LatLng(6.9147, 79.8601);

  @override
  Widget build(BuildContext context) {
    final selectedPoint = position ?? breakdownPoint;
    final activeProviderPoint = providerPosition ?? providerPoint;
    return ClipRRect(
      borderRadius: BorderRadius.circular(RaRadius.sm),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: selectedPoint,
          initialZoom: 14.5,
          onTap: onPositionSelected == null
              ? null
              : (_, point) => onPositionSelected!(point),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.roadassist.app',
          ),
          if (showRoute)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints == null || routePoints!.isEmpty
                      ? [activeProviderPoint, selectedPoint]
                      : routePoints!,
                  color: raBlue,
                  strokeWidth: 5,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              Marker(
                point: selectedPoint,
                width: 54,
                height: 54,
                alignment: Alignment.topCenter,
                child: const _MapPin(
                  icon: Icons.directions_car,
                  color: raDanger,
                  label: 'Breakdown location',
                ),
              ),
              for (final point in providerPositions)
                Marker(
                  point: point,
                  width: 46,
                  height: 46,
                  alignment: Alignment.topCenter,
                  child: _MapPin(
                    icon: Icons.build,
                    color: point == selectedProviderPosition ? raGold : raBlue,
                    label: point == selectedProviderPosition
                        ? 'Selected service provider'
                        : 'Available service provider',
                  ),
                ),
              if ((showProviders || showRoute) && providerPositions.isEmpty)
                Marker(
                  point: activeProviderPoint,
                  width: 54,
                  height: 54,
                  alignment: Alignment.topCenter,
                  child: const _MapPin(
                    icon: Icons.build,
                    color: raBlue,
                    label: 'Service provider',
                  ),
                ),
            ],
          ),
          const RichAttributionWidget(
            attributions: [TextSourceAttribution('OpenStreetMap contributors')],
          ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    ),
  );
}

// ============================================================
// SHARED — INFO / IDENTITY
// ============================================================

class InfoStrip extends StatelessWidget {
  const InfoStrip({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title, value;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: RaSpace.md,
        vertical: 4,
      ),
      leading: IconBadge(icon),
      title: Text(title, style: RaText.title),
      subtitle: Text(value, style: RaText.caption),
    ),
  );
}

class ProviderTile extends StatelessWidget {
  const ProviderTile({
    super.key,
    required this.name,
    required this.company,
    required this.distance,
    required this.eta,
    required this.rating,
    this.completedJobs = 0,
    this.services = const [],
    this.assetPath,
    required this.selected,
    required this.onTap,
  });
  final String name, company, distance, eta, rating;
  final int completedJobs;
  final List<String> services;
  final String? assetPath;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    color: selected
        ? (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF213A4B)
              : raPale)
        : Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(RaRadius.md),
      side: BorderSide(
        color: selected ? raBlue : raLine,
        width: selected ? 1.6 : 1,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(RaRadius.md),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(RaSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                assetPath == null
                    ? ProfileInitials(name: name)
                    : AssetAvatar(label: 'Provider', assetPath: assetPath),
                const SizedBox(width: RaSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: RaText.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        company,
                        style: RaText.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: RaSpace.sm),
                      Row(
                        children: [
                          const Icon(
                            Icons.directions_car_filled,
                            size: 13,
                            color: raBlue,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '$distance · ETA $eta',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: raBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: raGold),
                        const SizedBox(width: 2),
                        Text(
                          rating,
                          style: const TextStyle(
                            color: raGold,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: RaSpace.md),
                    Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      color: selected ? raBlue : raFaint,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: RaSpace.sm),
            Wrap(
              spacing: RaSpace.sm,
              runSpacing: RaSpace.xs,
              children: [
                _ProviderMetricChip(
                  icon: Icons.task_alt_rounded,
                  label: completedJobs == 0
                      ? 'No completed jobs yet'
                      : '$completedJobs completed',
                ),
                _ProviderMetricChip(
                  icon: Icons.build_outlined,
                  label: services.isEmpty
                      ? 'Services pending'
                      : services.join(', '),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProviderMetricChip extends StatelessWidget {
  const _ProviderMetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 250),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(RaRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: raBlue),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RaText.caption,
          ),
        ),
      ],
    ),
  );
}

class ProfileInitials extends StatelessWidget {
  const ProfileInitials({
    super.key,
    required this.name,
    this.radius = 28,
    this.foregroundColor = raBlue,
    this.background,
  });

  final String name;
  final double radius;
  final Color foregroundColor;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    final initials = words.isEmpty
        ? '?'
        : words.take(2).map((word) => word[0].toUpperCase()).join();
    return CircleAvatar(
      radius: radius,
      backgroundColor:
          background ??
          (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF263D4C)
              : raPale),
      child: Text(
        initials,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w800,
          fontSize: radius * .6,
        ),
      ),
    );
  }
}

class AssetAvatar extends StatelessWidget {
  const AssetAvatar({
    super.key,
    required this.label,
    this.assetPath,
    this.radius = 28,
  });
  final String label;
  final String? assetPath;
  final double radius;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: CircleAvatar(
      radius: radius,
      backgroundColor: raPale,
      backgroundImage: assetPath == null ? null : AssetImage(assetPath!),
      child: assetPath == null
          ? const Icon(Icons.person, color: raBlue, size: 30)
          : null,
    ),
  );
}

class SummaryRow extends StatelessWidget {
  const SummaryRow(this.label, this.value, {super.key, this.strong = false});
  final String label, value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: strong ? RaText.title : RaText.bodyMuted),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: strong
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: strong ? 17 : 13,
            ),
          ),
        ),
      ],
    ),
  );
}

class FilterRow extends StatelessWidget {
  const FilterRow({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    height: 46,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFE9EDF4),
      borderRadius: BorderRadius.circular(RaRadius.sm),
    ),
    child: Row(
      children: List.generate(3, (index) {
        const labels = ['All', 'Completed', 'Cancelled'];
        final active = selected == index;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 2 ? 0 : 3),
            child: Material(
              color: active ? raNavy : Colors.transparent,
              borderRadius: BorderRadius.circular(RaRadius.sm - 2),
              child: InkWell(
                onTap: () => onSelected(index),
                borderRadius: BorderRadius.circular(RaRadius.sm - 2),
                child: Center(
                  child: Text(
                    labels[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? Colors.white : raInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    ),
  );
}

class HistoryCard extends StatelessWidget {
  const HistoryCard(
    this.title,
    this.provider,
    this.vehicle,
    this.cost,
    this.completed, {
    super.key,
  });
  final String title, provider, vehicle, cost;
  final bool completed;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(RaSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(Icons.car_repair, size: 34),
              const SizedBox(width: RaSpace.sm),
              Expanded(child: Text(title, style: RaText.title)),
              StatusPill(
                label: completed ? 'Completed' : 'Cancelled',
                tone: completed ? RaTone.success : RaTone.danger,
              ),
            ],
          ),
          const Divider(height: RaSpace.xxl),
          SummaryRow('Provider', provider),
          SummaryRow('Vehicle', vehicle),
          const Divider(),
          SummaryRow('Total Cost', cost, strong: true),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () =>
                  push(context, const DriverRequestDetailsScreen()),
              child: const Text('View Details'),
            ),
          ),
        ],
      ),
    ),
  );
}

// ============================================================
// SHARED — DESIGN SYSTEM PRIMITIVES
// (icon containers + status pills used across every screen)
// ============================================================

enum RaTone { success, danger, warning, info, neutral }

class IconBadge extends StatelessWidget {
  const IconBadge(
    this.icon, {
    super.key,
    this.color = raBlue,
    this.background,
    this.size = 40,
    this.iconSize,
  });
  final IconData icon;
  final Color color;
  final Color? background;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color:
          background ??
          (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF263D4C)
              : raPale),
      borderRadius: BorderRadius.circular(size * 0.3),
    ),
    child: Icon(icon, color: color, size: iconSize ?? size * 0.5),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.tone = RaTone.info,
    this.dot = true,
  });
  final String label;
  final RaTone tone;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (tone) {
      RaTone.success => (raSuccessPale, raSuccess),
      RaTone.danger => (raDangerPale, raDanger),
      RaTone.warning => (raGoldPale, const Color(0xFFA5670C)),
      RaTone.info => (raPale, raBlue),
      RaTone.neutral => (const Color(0xFFF0F2F6), raMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(RaRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
