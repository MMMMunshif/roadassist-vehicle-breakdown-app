part of '../screens.dart';

class ProvidersScreen extends StatefulWidget {
  const ProvidersScreen({super.key, required this.draft});
  final RequestDraft draft;
  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

double? _providerDistanceKm(Map<String, dynamic> data, RequestDraft draft) {
  final latitude = (data['latitude'] as num?)?.toDouble();
  final longitude = (data['longitude'] as num?)?.toDouble();
  if (latitude == null || longitude == null) return null;
  return Geolocator.distanceBetween(
        draft.latitude,
        draft.longitude,
        latitude,
        longitude,
      ) /
      1000;
}

bool _providerMatchesDraft(Map<String, dynamic> data, RequestDraft draft) {
  if ((data['activeRequestId'] as String? ?? '').isNotEmpty) return false;
  final services = (data['services'] as List<dynamic>? ?? const [])
      .whereType<String>()
      .toList();
  if (services.isNotEmpty &&
      !draft.issues.every((issue) => services.contains(issue))) {
    return false;
  }
  final distanceKm = _providerDistanceKm(data, draft);
  if (distanceKm == null) return true;
  final radiusText = data['serviceRadius'] as String? ?? '15 km';
  final radius =
      double.tryParse(RegExp(r'\d+').firstMatch(radiusText)?.group(0) ?? '') ??
      15;
  return distanceKm <= radius;
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  String? selectedId;
  String? selectedName;

  @override
  void initState() {
    super.initState();
    selectedId = widget.draft.preferredProviderId.isEmpty
        ? null
        : widget.draft.preferredProviderId;
    selectedName = widget.draft.provider.isEmpty ? null : widget.draft.provider;
  }

  Future<void> reviewRequest() async {
    final selectedDraft = widget.draft.copyWith(
      provider: selectedName ?? 'Available Provider',
      preferredProviderId: selectedId,
    );
    await RequestDraftStore().save(selectedDraft);
    if (!mounted) return;
    push(context, ReviewScreen(draft: selectedDraft));
  }

  void scheduleProviderSelection(String? id, String? name) {
    if (selectedId == id && selectedName == name) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        selectedId = id;
        selectedName = name;
      });
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nearby Providers')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(RaSpace.xl),
              children: [
                const StepEyebrow(step: 3, of: 4),
                const SizedBox(height: RaSpace.md),
                InfoStrip(
                  icon: Icons.location_on,
                  title: 'Your location',
                  value: widget.draft.location,
                ),
                const SizedBox(height: RaSpace.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(RaRadius.md),
                  child: SizedBox(
                    height: 185,
                    child: _NearbyProvidersMap(
                      draft: widget.draft,
                      selectedId: selectedId,
                    ),
                  ),
                ),
                const SizedBox(height: RaSpace.xl),
                const SectionTitle(
                  'Available Technicians',
                  action: 'List / Map',
                ),
                const SizedBox(height: RaSpace.md),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: AuthService().watchOnlineProviders(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const EmptyState(
                        icon: Icons.cloud_off,
                        title: 'Unable to load providers',
                        message: 'Check your connection and try again.',
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final providers = snapshot.data!.docs
                        .where(
                          (provider) => _providerMatchesDraft(
                            provider.data(),
                            widget.draft,
                          ),
                        )
                        .toList();
                    providers.sort((a, b) {
                      final aDistance =
                          _providerDistanceKm(a.data(), widget.draft) ??
                          double.infinity;
                      final bDistance =
                          _providerDistanceKm(b.data(), widget.draft) ??
                          double.infinity;
                      return aDistance.compareTo(bDistance);
                    });
                    if (providers.isEmpty) {
                      scheduleProviderSelection(null, null);
                      return const EmptyState(
                        icon: Icons.person_search,
                        title: 'No matching providers nearby',
                        message:
                            'A provider must be online, support this service and be within range.',
                      );
                    }
                    if (selectedId != null &&
                        !providers.any(
                          (provider) => provider.id == selectedId,
                        )) {
                      scheduleProviderSelection(null, null);
                    }
                    return Column(
                      children: [
                        ListTile(
                          title: const Text(
                            'Receive offers from all suitable providers',
                          ),
                          subtitle: const Text(
                            'Compare prices before choosing',
                          ),
                          trailing: Icon(
                            selectedId == null
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                          ),
                          onTap: () => setState(() {
                            selectedId = null;
                            selectedName = null;
                          }),
                        ),
                        ...providers.map((provider) {
                          final data = provider.data();
                          final name =
                              data['displayName'] as String? ??
                              'Service Provider';
                          final distanceKm = _providerDistanceKm(
                            data,
                            widget.draft,
                          );
                          final rating =
                              (data['averageRating'] as num?)?.toDouble() ?? 0;
                          final completedJobs =
                              (data['completedJobs'] as num?)?.toInt() ?? 0;
                          final responseMinutes =
                              (data['averageResponseMinutes'] as num?)
                                  ?.toDouble() ??
                              0;
                          final services =
                              (data['services'] as List<dynamic>? ?? const [])
                                  .whereType<String>()
                                  .toList();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: RaSpace.sm),
                            child: ProviderTile(
                              name: name,
                              company: 'RoadAssist Service Provider',
                              distance: distanceKm == null
                                  ? 'Location pending'
                                  : '${distanceKm.toStringAsFixed(1)} km away',
                              eta: responseMinutes > 0
                                  ? '${responseMinutes.ceil()} min response'
                                  : 'response pending',
                              rating: rating > 0
                                  ? rating.toStringAsFixed(1)
                                  : 'New',
                              completedJobs: completedJobs,
                              services: services,
                              selected: selectedId == provider.id,
                              onTap: () => setState(() {
                                selectedId = provider.id;
                                selectedName = name;
                              }),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          BottomAction(
            label: 'Review Request',
            enabled: true,
            onTap: reviewRequest,
          ),
        ],
      ),
    ),
  );
}
