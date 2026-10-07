part of '../../screens.dart';

class ProviderDirectoryScreen
    extends StatefulWidget {
  const ProviderDirectoryScreen({
    super.key,
  });

  @override
  State<ProviderDirectoryScreen>
      createState() =>
          _ProviderDirectoryScreenState();
}

class _ProviderDirectoryScreenState
    extends State<ProviderDirectoryScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Nearby Providers',
          ),
        ),
        body: const Padding(
          padding: EdgeInsets.all(20),
          child: EmptyState(
            icon: Icons.login_outlined,
            title: 'Sign in required',
            message:
                'Sign in as a driver to search online providers.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Available Providers',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
      ),
      body: StreamBuilder<
          QuerySnapshot<
              Map<String, dynamic>>>(
        stream:
            AuthService().watchOnlineProviders(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyState(
                icon:
                    Icons.cloud_off_outlined,
                title:
                    'Unable to load providers',
                message:
                    'Check your connection and try again.',
              ),
            );
          }

          if (!snapshot.hasData) {
            return const _DriverProviderDirectoryLoading();
          }

          final verified =
              snapshot.data!.docs.where(
            (doc) {
              return _providerHasCurrentVerification(
                doc.data(),
              );
            },
          ).toList();

          final providers =
              verified.where((doc) {
            final name =
                (doc.data()['displayName']
                            as String? ??
                        '')
                    .toLowerCase();

            return name.contains(query);
          }).toList();

          return CustomScrollView(
            physics:
                const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(
                  18,
                  10,
                  18,
                  0,
                ),
                sliver:
                    SliverToBoxAdapter(
                  child:
                      _DriverProviderDirectoryHeader(
                    count:
                        verified.length,
                  ),
                ),
              ),

              SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(
                  18,
                  15,
                  18,
                  0,
                ),
                sliver:
                    SliverToBoxAdapter(
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        query = value
                            .trim()
                            .toLowerCase();
                      });
                    },
                    decoration:
                        InputDecoration(
                      hintText:
                          'Search provider by name',
                      prefixIcon:
                          const Icon(
                        Icons.search_rounded,
                      ),
                      suffixIcon:
                          query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip:
                                      'Clear search',
                                  onPressed:
                                      () {
                                    setState(
                                      () {
                                        query =
                                            '';
                                      },
                                    );
                                  },
                                  icon:
                                      const Icon(
                                    Icons
                                        .close_rounded,
                                  ),
                                ),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 21),
              ),

              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 18,
                ),
                sliver:
                    SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          query.isEmpty
                              ? 'Online now'
                              : 'Search results',
                          style: GoogleFonts
                              .plusJakartaSans(
                            fontSize: 16,
                            fontWeight:
                                FontWeight
                                    .w800,
                            letterSpacing:
                                -.3,
                            color: colors
                                .onSurface,
                          ),
                        ),
                      ),

                      Text(
                        '${providers.length}',
                        style: GoogleFonts
                            .plusJakartaSans(
                          fontSize: 10,
                          fontWeight:
                              FontWeight.w700,
                          color: colors
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 11),
              ),

              if (providers.isEmpty)
                SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    18,
                    0,
                    18,
                    24,
                  ),
                  sliver:
                      SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons
                          .person_search_outlined,
                      title: query.isEmpty
                          ? 'No providers online'
                          : 'No matching provider',
                      message: query.isEmpty
                          ? 'Verified providers will appear automatically when they become available.'
                          : 'Try another provider name.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 18,
                  ),
                  sliver:
                      SliverList.separated(
                    itemCount:
                        providers.length,
                    separatorBuilder:
                        (_, __) =>
                            const SizedBox(
                      height: 10,
                    ),
                    itemBuilder:
                        (context, index) {
                      final provider =
                          providers[index]
                              .data();

                      return _DriverProviderDirectoryCard(
                        data: provider,
                      );
                    },
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ),

              SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(
                  18,
                  0,
                  18,
                  32,
                ),
                sliver:
                    SliverToBoxAdapter(
                  child: Container(
                    padding:
                        const EdgeInsets.all(
                      17,
                    ),
                    decoration:
                        BoxDecoration(
                      color: colors.primary
                          .withValues(
                        alpha: .075,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(20),
                      border: Border.all(
                        color: colors.primary
                            .withValues(
                          alpha: .14,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'Need roadside assistance?',
                          style: GoogleFonts
                              .plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight:
                                FontWeight
                                    .w700,
                            color: colors
                                .onSurface,
                          ),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        Text(
                          'Start a request so RoadAssist can match providers to your vehicle, issue and location.',
                          style: GoogleFonts
                              .plusJakartaSans(
                            fontSize: 10.5,
                            height: 1.45,
                            color: colors
                                .onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(
                          height: 13,
                        ),
                        SizedBox(
                          width:
                              double.infinity,
                          child:
                              FilledButton.icon(
                            onPressed: () {
                              push(
                                context,
                                const AssistanceTypeScreen(),
                              );
                            },
                            icon: const Icon(
                              Icons
                                  .add_road_rounded,
                            ),
                            label: const Text(
                              'Start Assistance',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DriverProviderDirectoryHeader
    extends StatelessWidget {
  const _DriverProviderDirectoryHeader({
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF075A9F),
            Color(0xFF087E75),
          ],
        ),
        borderRadius:
            BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white
                  .withValues(alpha: .13),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons
                  .engineering_outlined,
              color: Colors.white,
              size: 25,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  count > 0
                      ? '$count verified ${count == 1 ? 'provider' : 'providers'} online'
                      : 'Provider network',
                  style: GoogleFonts
                      .plusJakartaSans(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Availability updates automatically as providers go online or offline.',
                  style: GoogleFonts
                      .plusJakartaSans(
                    color: Colors.white
                        .withValues(
                      alpha: .78,
                    ),
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Container(
            width: 9,
            height: 9,
            decoration:
                const BoxDecoration(
              color: Color(0xFF65E3B5),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverProviderDirectoryCard
    extends StatelessWidget {
  const _DriverProviderDirectoryCard({
    required this.data,
  });

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final dark =
        theme.brightness == Brightness.dark;

    final name =
        data['displayName'] as String? ??
            'Service Provider';

    final services =
        (data['services']
                    as List<dynamic>? ??
                const [])
            .whereType<String>()
            .where(
              (value) =>
                  value.trim().isNotEmpty,
            )
            .toList();

    final radius =
        data['serviceRadius'] as String?;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFF0D1D2B)
            : Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .48),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ProfileInitials(
                    name: name,
                    radius: 24,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration:
                          BoxDecoration(
                        color: raSuccess,
                        shape:
                            BoxShape.circle,
                        border: Border.all(
                          color: dark
                              ? const Color(
                                  0xFF0D1D2B,
                                )
                              : Colors.white,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: GoogleFonts
                          .plusJakartaSans(
                        color:
                            colors.onSurface,
                        fontSize: 13.5,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Online • accepting requests',
                      style: GoogleFonts
                          .plusJakartaSans(
                        color: raSuccess,
                        fontSize: 9.5,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const StatusPill(
                label: 'Available',
                tone: RaTone.success,
              ),
            ],
          ),

          if (services.isNotEmpty ||
              (radius != null &&
                  radius
                      .trim()
                      .isNotEmpty)) ...[
            const SizedBox(height: 13),

            Divider(
              height: 1,
              color: colors.outlineVariant
                  .withValues(alpha: .40),
            ),

            const SizedBox(height: 12),
          ],

          if (services.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final service
                    in services.take(4))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration:
                        BoxDecoration(
                      color: colors
                          .primary
                          .withValues(
                        alpha: .07,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(999),
                    ),
                    child: Text(
                      service,
                      style: GoogleFonts
                          .plusJakartaSans(
                        color:
                            colors.primary,
                        fontSize: 8.5,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),

          if (radius != null &&
              radius.trim().isNotEmpty) ...[
            if (services.isNotEmpty)
              const SizedBox(height: 10),

            Row(
              children: [
                Icon(
                  Icons.route_outlined,
                  size: 15,
                  color: colors
                      .onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Service coverage: $radius',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 9.5,
                    color: colors
                        .onSurfaceVariant,
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

class _DriverProviderDirectoryLoading
    extends StatelessWidget {
  const _DriverProviderDirectoryLoading();

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          height: 104,
          decoration: BoxDecoration(
            color: colors
                .surfaceContainerHighest,
            borderRadius:
                BorderRadius.circular(23),
          ),
        ),

        const SizedBox(height: 15),

        Container(
          height: 56,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius:
                BorderRadius.circular(14),
          ),
        ),

        const SizedBox(height: 24),

        for (var i = 0;
            i < 4;
            i++) ...[
          Container(
            height: 125,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius:
                  BorderRadius.circular(
                20,
              ),
              border: Border.all(
                color:
                    colors.outlineVariant,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}