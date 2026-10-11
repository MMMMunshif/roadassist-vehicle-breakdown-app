part of '../../screens.dart';

class ProviderDirectoryScreen extends StatefulWidget {
  const ProviderDirectoryScreen({super.key});

  @override
  State<ProviderDirectoryScreen> createState() =>
      _ProviderDirectoryScreenState();
}

class _ProviderDirectoryScreenState extends State<ProviderDirectoryScreen> {
  final searchController = TextEditingController();

  String query = '';
  Timer? availabilityClock;

  @override
  void initState() {
    super.initState();
    availabilityClock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    availabilityClock?.cancel();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    if (!signedIn) {
      return RaDriverScaffold(
        appBar: AppBar(title: const RaDriverAppBarTitle('Available Providers')),
        body: const Padding(
          padding: EdgeInsets.all(18),
          child: EmptyState(
            icon: Icons.login_outlined,
            title: 'Sign in required',
            message: 'Sign in as a driver to search online providers.',
          ),
        ),
      );
    }

    return RaDriverScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: RaDriverAppBarTitle(
          'Available Providers',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AuthService().watchOnlineProviders(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.all(18),
              child: EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Unable to load providers',
                message: 'Check your connection and try again.',
              ),
            );
          }

          if (!snapshot.hasData) {
            return const _RaProviderDirectoryLoading();
          }

          final verified = snapshot.data!.docs.where((document) {
            return _providerHasCurrentVerification(document.data()) &&
                _providerAvailabilityStatus(document.data()) == 'Online';
          }).toList();

          final providers = verified.where((document) {
            final data = document.data();

            final searchable = [
              data['displayName'],
              ...(data['services'] as List<dynamic>? ?? const []),
            ].join(' ').toLowerCase();

            return searchable.contains(query);
          }).toList();

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            children: [
              _RaProviderDirectoryHero(count: verified.length),

              const SizedBox(height: 15),

              TextField(
                controller: searchController,
                onChanged: (value) {
                  setState(() {
                    query = value.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by provider or service',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            searchController.clear();

                            setState(() {
                              query = '';
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),

              const SizedBox(height: 22),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      query.isEmpty ? 'Online now' : 'Search results',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${providers.length}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              if (providers.isEmpty)
                EmptyState(
                  icon: Icons.person_search_outlined,
                  title: query.isEmpty
                      ? 'No providers online'
                      : 'No matching provider',
                  message: query.isEmpty
                      ? 'Verified providers will appear automatically when they become available.'
                      : 'Try another provider name or service.',
                )
              else
                for (var index = 0; index < providers.length; index++) ...[
                  _RaProviderDirectoryCard(data: providers[index].data()),
                  if (index != providers.length - 1) const SizedBox(height: 9),
                ],

              const SizedBox(height: 22),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: .15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.add_road_rounded, color: colors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Need roadside assistance?',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Start a request so RoadAssist can match providers to your actual vehicle, issue and breakdown location.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        height: 1.4,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        push(context, const AssistanceTypeScreen());
                      },
                      icon: const Icon(Icons.add_road_rounded),
                      label: const Text('Start Assistance'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RaProviderDirectoryHero extends StatelessWidget {
  const _RaProviderDirectoryHero({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF0A497F), Color(0xFF075A68)]
              : const [Color(0xFF075BA8), Color(0xFF078C7E)],
        ),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          Container(
            width: 49,
            height: 49,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.engineering_outlined,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count > 0
                      ? '$count verified ${count == 1 ? 'provider' : 'providers'} online'
                      : 'Provider network',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Availability updates automatically as verified providers go online or offline.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFF65E3B5),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaProviderDirectoryCard extends StatelessWidget {
  const _RaProviderDirectoryCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final name = data['displayName']?.toString().trim() ?? '';

    final providerName = name.isEmpty ? 'Service Provider' : name;

    final services = (data['services'] as List<dynamic>? ?? const [])
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList();

    final radius = data['serviceRadius']?.toString().trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF0D2237)
            : colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ProfileInitials(name: providerName, radius: 23),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: raSuccess,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.brightness == Brightness.dark
                              ? const Color(0xFF0D2237)
                              : colors.surface,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      providerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Online â€¢ accepting requests',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: raSuccess,
                      ),
                    ),
                  ],
                ),
              ),

              const StatusPill(label: 'Available', tone: RaTone.success),
            ],
          ),

          if (services.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final service in services.take(4))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      service,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ],

          if (radius.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.route_outlined,
                  size: 14,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Service coverage: $radius',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RaProviderDirectoryLoading extends StatelessWidget {
  const _RaProviderDirectoryLoading();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          height: 105,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(23),
          ),
        ),
        const SizedBox(height: 15),
        Container(
          height: 55,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        const SizedBox(height: 22),
        for (var index = 0; index < 4; index++) ...[
          Container(
            height: 125,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.outlineVariant),
            ),
          ),
          const SizedBox(height: 9),
        ],
      ],
    );
  }
}
