part of '../../screens.dart';

class ProvidersScreen extends StatefulWidget {
  const ProvidersScreen({super.key, required this.draft});

  final RequestDraft draft;

  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

double? _providerDistanceKm(Map<String, dynamic> data, RequestDraft draft) {
  final latitude = (data['latitude'] as num?)?.toDouble();

  final longitude = (data['longitude'] as num?)?.toDouble();

  if (latitude == null || longitude == null) {
    return null;
  }

  return Geolocator.distanceBetween(
        draft.latitude,
        draft.longitude,
        latitude,
        longitude,
      ) /
      1000;
}

String _providerAvailabilityStatus(Map<String, dynamic> data) {
  return ProviderAvailability.status(
    data,
    DateTime.now(),
    locationUpdatedAt: (data['locationUpdatedAt'] as Timestamp?)?.toDate(),
    overrideUntil: (data['hoursOverrideUntil'] as Timestamp?)?.toDate(),
  );
}

String _providerAvailabilityExplanation(Map<String, dynamic> data) {
  if (data['online'] != true)
    return 'Turn on availability from your dashboard when you are ready to help.';
  final updated = (data['locationUpdatedAt'] as Timestamp?)?.toDate();
  if (!ProviderAvailability.hasFreshLocation(updated, DateTime.now())) {
    return 'Your online switch is on, but your live location is missing or expired. Allow browser location access, then pull down on the dashboard to refresh your location.';
  }
  final status = _providerAvailabilityStatus(data);
  if (status == 'Busy')
    return 'Complete your active job before accepting another request.';
  if (status == 'Paused')
    return 'Requests are paused. Resume accepting requests from your availability settings.';
  if (status == 'Outside working hours')
    return 'Your configured working hours are closed. Update your working hours or use the availability override.';
  return 'Your availability is being updated.';
}

bool _providerLocationOutdated(Map<String, dynamic> data) {
  final updated = (data['locationUpdatedAt'] as Timestamp?)?.toDate();

  if (updated == null) {
    return true;
  }

  return DateTime.now().difference(updated) > const Duration(minutes: 10);
}

bool _providerMatchesDraft(Map<String, dynamic> data, RequestDraft draft) {
  if (!_providerHasCurrentVerification(data) ||
      _providerAvailabilityStatus(data) != 'Online') {
    return false;
  }

  final vehicles = data['vehicleTypes'] as List? ?? const [];

  if (!vehicles.contains(draft.vehicleType)) {
    return false;
  }

  if ((data['activeRequestId'] as String? ?? '').isNotEmpty) {
    return false;
  }

  final services = (data['services'] as List<dynamic>? ?? const [])
      .whereType<String>()
      .toList();

  if (services.isNotEmpty && !draft.issues.every(services.contains)) {
    return false;
  }

  final distance = _providerDistanceKm(data, draft);

  if (distance == null) {
    return false;
  }

  final radiusText = data['serviceRadius'] as String? ?? '15 km';

  final radiusMatch = RegExp(r'\d+').firstMatch(radiusText)?.group(0);

  final radius = double.tryParse(radiusMatch ?? '') ?? 15;

  return distance <= radius;
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  Timer? availabilityClock;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> onlineProviders;

  String? selectedId;
  String? selectedName;

  @override
  void initState() {
    super.initState();

    onlineProviders = AuthService().watchOnlineProviders();

    selectedId = widget.draft.preferredProviderId.isEmpty
        ? null
        : widget.draft.preferredProviderId;

    selectedName = widget.draft.provider.isEmpty ? null : widget.draft.provider;

    availabilityClock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    availabilityClock?.cancel();

    super.dispose();
  }

  Future<void> reviewRequest() async {
    final selectedDraft = widget.draft.copyWith(
      provider: selectedName ?? 'Available Provider',
      preferredProviderId: selectedId,
    );

    await RequestDraftStore().save(selectedDraft);

    if (!mounted) {
      return;
    }

    push(context, ReviewScreen(draft: selectedDraft));
  }

  void selectAllOffers() {
    setState(() {
      selectedId = null;
      selectedName = null;
    });
  }

  void resetSelectionIfMissing(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> providers,
  ) {
    if (selectedId == null) {
      return;
    }

    final stillAvailable = providers.any(
      (provider) => provider.id == selectedId,
    );

    if (stillAvailable) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        selectedId = null;
        selectedName = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return RaDriverScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: RaDriverAppBarTitle(
          'Choose Provider',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  const _RaProvidersProgress(),

                  const SizedBox(height: 16),

                  const _RaProvidersHero(),

                  const SizedBox(height: 16),

                  _RaProviderLocationSummary(draft: widget.draft),

                  const SizedBox(height: 25),

                  Text(
                    'How do you want to request help?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.35,
                      color: colors.onSurface,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Compare offers from suitable providers, or direct the request to one specific provider.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      height: 1.4,
                      color: colors.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 12),

                  _RaAllProvidersCard(
                    selected: selectedId == null,
                    onTap: selectAllOffers,
                  ),

                  const SizedBox(height: 26),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Available providers',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.35,
                              ),
                            ),

                            const SizedBox(height: 3),

                            Text(
                              'Only verified, online and suitable providers are shown.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: onlineProviders,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const EmptyState(
                          icon: Icons.cloud_off_outlined,
                          title: 'Unable to load providers',
                          message: 'Check your connection and try again.',
                        );
                      }

                      if (!snapshot.hasData) {
                        return const _RaProvidersLoading();
                      }

                      final providers = snapshot.data!.docs.where((provider) {
                        return _providerMatchesDraft(
                          provider.data(),
                          widget.draft,
                        );
                      }).toList();

                      providers.sort((first, second) {
                        final firstDistance =
                            _providerDistanceKm(first.data(), widget.draft) ??
                            double.infinity;

                        final secondDistance =
                            _providerDistanceKm(second.data(), widget.draft) ??
                            double.infinity;

                        return firstDistance.compareTo(secondDistance);
                      });

                      resetSelectionIfMissing(providers);

                      if (providers.isEmpty) {
                        return const _RaNoProviders();
                      }

                      return Column(
                        children: [
                          for (
                            var index = 0;
                            index < providers.length;
                            index++
                          ) ...[
                            _RaProviderChoiceCard(
                              data: providers[index].data(),
                              draft: widget.draft,
                              selected: selectedId == providers[index].id,
                              onTap: () {
                                final provider = providers[index];

                                final data = provider.data();

                                setState(() {
                                  selectedId = provider.id;

                                  selectedName =
                                      data['displayName'] as String? ??
                                      'Service Provider';
                                });
                              },
                            ),

                            if (index != providers.length - 1)
                              const SizedBox(height: 9),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            _RaProvidersBottomBar(
              selectedProvider: selectedName,
              onContinue: reviewRequest,
            ),
          ],
        ),
      ),
    );
  }
}

class _RaProvidersProgress extends StatelessWidget {
  const _RaProvidersProgress();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'PROVIDER',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  letterSpacing: .8,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ),

            const Spacer(),

            Text(
              'Next: Review',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),

        const SizedBox(height: 7),

        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: .88,
            minHeight: 5,
            backgroundColor: colors.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _RaProvidersHero extends StatelessWidget {
  const _RaProvidersHero();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF0B477D), Color(0xFF08645D)]
              : const [Color(0xFF075BA8), Color(0xFF078C7E)],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            bottom: -31,
            child: Icon(
              Icons.handyman_outlined,
              size: 130,
              color: Colors.white.withValues(alpha: .06),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.person_search_outlined,
                  color: Colors.white,
                  size: 25,
                ),
              ),

              const SizedBox(height: 15),

              Text(
                'Choose how you get help',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.5,
                ),
              ),

              const SizedBox(height: 6),

              SizedBox(
                width: 295,
                child: Text(
                  'Let several suitable providers send offers, or request one provider directly.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: .80),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RaProviderLocationSummary extends StatelessWidget {
  const _RaProviderLocationSummary({required this.draft});

  final RequestDraft draft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF0D2237)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 41,
            height: 41,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.location_on_outlined, color: colors.primary),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Provider search location',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  draft.location,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.4,
                    color: colors.onSurfaceVariant,
                  ),
                ),

                if (draft.landmark.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Landmark: ${draft.landmark}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RaAllProvidersCard extends StatelessWidget {
  const _RaAllProvidersCard({required this.selected, required this.onTap});

  final bool selected;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Material(
      color: selected
          ? colors.primary.withValues(alpha: .07)
          : theme.brightness == Brightness.dark
          ? const Color(0xFF0D2237)
          : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? colors.primary.withValues(alpha: .48)
                  : colors.outlineVariant.withValues(alpha: .45),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 47,
                height: 47,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.compare_arrows_rounded,
                  color: colors.primary,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Receive provider offers',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: selected ? colors.primary : colors.outline,
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    Text(
                      'Suitable providers can review your request and submit offers for you to compare before selecting one.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        height: 1.4,
                        color: colors.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Compare before approval',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaProviderChoiceCard extends StatelessWidget {
  const _RaProviderChoiceCard({
    required this.data,
    required this.draft,
    required this.selected,
    required this.onTap,
  });

  final Map<String, dynamic> data;

  final RequestDraft draft;

  final bool selected;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final name = data['displayName'] as String? ?? 'Service Provider';

    final distance = _providerDistanceKm(data, draft);

    final stale = _providerLocationOutdated(data);

    final rating = (data['averageRating'] as num?)?.toDouble();

    final completedJobs = (data['completedJobs'] as num?)?.toInt();

    final responseMinutes = (data['averageResponseMinutes'] as num?)
        ?.toDouble();

    final services = (data['services'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();

    return Material(
      color: selected
          ? colors.primary.withValues(alpha: .07)
          : theme.brightness == Brightness.dark
          ? const Color(0xFF0D2237)
          : Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? colors.primary.withValues(alpha: .48)
                  : colors.outlineVariant.withValues(alpha: .45),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProfileInitials(name: name, radius: 24),

                  const SizedBox(width: 11),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),

                            Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: selected ? colors.primary : colors.outline,
                              size: 21,
                            ),
                          ],
                        ),

                        const SizedBox(height: 5),

                        const Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _RaProviderBadge(
                              icon: Icons.verified_outlined,
                              label: 'Verified',
                            ),
                            _RaProviderBadge(
                              icon: Icons.circle,
                              label: 'Online',
                              success: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 13),

              Wrap(
                spacing: 12,
                runSpacing: 7,
                children: [
                  _RaProviderFact(
                    icon: Icons.location_on_outlined,
                    value: stale
                        ? 'Location needs confirmation'
                        : distance == null
                        ? 'Distance unavailable'
                        : '${distance.toStringAsFixed(1)} km away',
                  ),

                  if (rating != null && rating > 0)
                    _RaProviderFact(
                      icon: Icons.star_outline_rounded,
                      value: '${rating.toStringAsFixed(1)} rating',
                    ),

                  if (completedJobs != null && completedJobs > 0)
                    _RaProviderFact(
                      icon: Icons.task_alt_rounded,
                      value: '$completedJobs completed',
                    ),

                  if (responseMinutes != null && responseMinutes > 0)
                    _RaProviderFact(
                      icon: Icons.schedule_outlined,
                      value: '${responseMinutes.ceil()} min response',
                    ),
                ],
              ),

              if (services.isNotEmpty) ...[
                const SizedBox(height: 12),

                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final service in services.take(3))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest.withValues(
                            alpha: .45,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          service,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    if (services.length > 3)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest.withValues(
                            alpha: .45,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '+${services.length - 3}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              if (stale) ...[
                const SizedBox(height: 11),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: raGold.withValues(alpha: .075),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_searching_rounded,
                        size: 17,
                        color: raGold,
                      ),

                      const SizedBox(width: 7),

                      Expanded(
                        child: Text(
                          'Provider location may be outdated. Confirm their location after connecting.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            height: 1.4,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RaProviderBadge extends StatelessWidget {
  const _RaProviderBadge({
    required this.icon,
    required this.label,
    this.success = false,
  });

  final IconData icon;
  final String label;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final tone = success ? raSuccess : colors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: tone),

          const SizedBox(width: 4),

          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaProviderFact extends StatelessWidget {
  const _RaProviderFact({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colors.onSurfaceVariant),

        const SizedBox(width: 4),

        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RaNoProviders extends StatelessWidget {
  const _RaNoProviders();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF0D2237)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      child: Column(
        children: [
          Container(
            width: 61,
            height: 61,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(19),
            ),
            child: Icon(
              Icons.person_search_outlined,
              color: colors.primary,
              size: 29,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'No matching provider online right now',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'You can still continue with provider offers. Suitable providers can respond when your request becomes available.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              height: 1.4,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaProvidersLoading extends StatelessWidget {
  const _RaProvidersLoading();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Finding suitable providers…'),
        ],
      ),
    );
  }
}

class _RaProvidersBottomBar extends StatelessWidget {
  const _RaProvidersBottomBar({
    required this.selectedProvider,
    required this.onContinue,
  });

  final String? selectedProvider;

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: .45)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  selectedProvider == null
                      ? Icons.compare_arrows_rounded
                      : Icons.person_pin_circle_outlined,
                  size: 16,
                  color: colors.primary,
                ),

                const SizedBox(width: 6),

                Expanded(
                  child: Text(
                    selectedProvider == null
                        ? 'Receive and compare provider offers'
                        : 'Requesting $selectedProvider',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 7),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onContinue,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Review Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
