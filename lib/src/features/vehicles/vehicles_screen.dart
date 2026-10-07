part of '../../screens.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({
    super.key,
    this.selecting = false,
  });

  final bool selecting;

  @override
  State<VehiclesScreen> createState() =>
      _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  late final VehicleService service;
  late Stream<List<Vehicle>> vehicles;

  bool busy = false;

  @override
  void initState() {
    super.initState();

    if (signedIn) {
      service = VehicleService();
      vehicles = service.watchVehicles();
    }
  }

  Future<void> action(
    Future<void> Function() work,
  ) async {
    setState(() {
      busy = true;
    });

    try {
      await work();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update vehicle: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  void edit([Vehicle? vehicle]) {
    push(
      context,
      VehicleEditorScreen(
        vehicle: vehicle,
      ),
    );
  }

  Future<void> archiveVehicle(
    Vehicle vehicle,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors =
            Theme.of(dialogContext)
                .colorScheme;

        return AlertDialog(
          icon: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius:
                  BorderRadius.circular(18),
            ),
            child: Icon(
              Icons
                  .archive_outlined,
              color: colors.error,
            ),
          ),
          title: const Text(
            'Archive this vehicle?',
          ),
          content: const Text(
            'It will be removed from your saved vehicle list. Existing assistance history will remain unchanged.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                false,
              ),
              child: const Text(
                'Keep Vehicle',
              ),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    colors.error,
                foregroundColor:
                    colors.onError,
              ),
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                true,
              ),
              child: const Text(
                'Archive',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true &&
        mounted) {
      await action(
        () => service.archive(
          vehicle.id,
        ),
      );
    }
  }

  Widget _header(
    BuildContext context,
    int count,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        RaSpace.xl,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            colors.primary,
            const Color(
              0xFF007D70,
            ),
          ],
        ),
        borderRadius:
            BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -24,
            child: Icon(
              Icons
                  .directions_car_filled_outlined,
              size: 130,
              color: Colors.white
                  .withValues(
                alpha: .07,
              ),
            ),
          ),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha: .14,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    17,
                  ),
                ),
                child: const Icon(
                  Icons
                      .garage_outlined,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(
                height: RaSpace.lg,
              ),
              Text(
                widget.selecting
                    ? 'Which vehicle needs help?'
                    : 'Your vehicles',
                style: theme
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                  color: Colors.white,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              Text(
                widget.selecting
                    ? 'Select a saved vehicle to fill the request details automatically.'
                    : count == 0
                        ? 'Save a vehicle once and reuse its information for future roadside requests.'
                        : '$count saved ${count == 1 ? 'vehicle' : 'vehicles'} ready for future requests.',
                style: theme
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                  color: Colors.white
                      .withValues(
                    alpha: .84,
                  ),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vehicleCard(
    BuildContext context,
    Vehicle vehicle,
    bool isDefault,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Material(
      color: colors.surface,
      borderRadius:
          BorderRadius.circular(21),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy
            ? null
            : () {
                if (widget.selecting) {
                  Navigator.pop(
                    context,
                    vehicle,
                  );
                } else {
                  edit(vehicle);
                }
              },
        child: Container(
          padding:
              const EdgeInsets.all(
            RaSpace.lg,
          ),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              21,
            ),
            border: Border.all(
              color: isDefault
                  ? colors.primary
                      .withValues(
                      alpha: .42,
                    )
                  : colors
                      .outlineVariant
                      .withValues(
                      alpha: .6,
                    ),
              width: isDefault
                  ? 1.4
                  : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration:
                        BoxDecoration(
                      color: colors
                          .primaryContainer,
                      borderRadius:
                          BorderRadius
                              .circular(
                        17,
                      ),
                    ),
                    child: Icon(
                      Icons
                          .directions_car_outlined,
                      color: colors
                          .onPrimaryContainer,
                      size: 27,
                    ),
                  ),

                  const SizedBox(
                    width: RaSpace.md,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                vehicle.label,
                                maxLines: 1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style: theme
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                  fontWeight:
                                      FontWeight
                                          .w900,
                                ),
                              ),
                            ),
                            if (isDefault)
                              Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color: colors
                                      .primaryContainer,
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    999,
                                  ),
                                ),
                                child: Text(
                                  'DEFAULT',
                                  style: theme
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                    color: colors
                                        .onPrimaryContainer,
                                    fontWeight:
                                        FontWeight
                                            .w900,
                                    letterSpacing:
                                        .5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          vehicle.registration,
                          style: theme
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                            color: colors
                                .onSurfaceVariant,
                            fontWeight:
                                FontWeight
                                    .w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: RaSpace.md,
              ),

              Wrap(
                spacing: RaSpace.sm,
                runSpacing: RaSpace.sm,
                children: [
                  _VehicleMetaChip(
                    icon: Icons
                        .local_gas_station_outlined,
                    label:
                        vehicle.fuelType,
                  ),
                  _VehicleMetaChip(
                    icon: Icons
                        .settings_outlined,
                    label:
                        vehicle.transmission,
                  ),
                ],
              ),

              const SizedBox(
                height: RaSpace.md,
              ),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.selecting
                          ? 'Tap to use this vehicle'
                          : 'Tap to edit vehicle details',
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ),

                  PopupMenuButton<String>(
                    enabled: !busy,
                    tooltip:
                        'Vehicle options',
                    onSelected:
                        (value) async {
                      if (value ==
                          'edit') {
                        edit(vehicle);
                        return;
                      }

                      if (value ==
                          'default') {
                        await action(
                          () => service
                              .setDefault(
                            vehicle.id,
                          ),
                        );
                        return;
                      }

                      if (value ==
                          'archive') {
                        await archiveVehicle(
                          vehicle,
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          contentPadding:
                              EdgeInsets.zero,
                          leading: Icon(
                            Icons
                                .edit_outlined,
                          ),
                          title: Text(
                            'Edit',
                          ),
                        ),
                      ),
                      if (!isDefault)
                        const PopupMenuItem(
                          value:
                              'default',
                          child: ListTile(
                            contentPadding:
                                EdgeInsets.zero,
                            leading: Icon(
                              Icons
                                  .star_outline_rounded,
                            ),
                            title: Text(
                              'Set as default',
                            ),
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'archive',
                        child: ListTile(
                          contentPadding:
                              EdgeInsets.zero,
                          leading: Icon(
                            Icons
                                .archive_outlined,
                          ),
                          title: Text(
                            'Archive',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,

      appBar: AppBar(
        title: Text(
          widget.selecting
              ? 'Choose Vehicle'
              : 'My Vehicles',
        ),
      ),

      floatingActionButton:
          signedIn &&
                  !widget.selecting
              ? FloatingActionButton
                  .extended(
                  onPressed:
                      busy
                          ? null
                          : () =>
                              edit(),
                  icon: const Icon(
                    Icons
                        .add_rounded,
                  ),
                  label: const Text(
                    'Add Vehicle',
                  ),
                )
              : null,

      body: !signedIn
          ? const Padding(
              padding:
                  EdgeInsets.all(
                RaSpace.lg,
              ),
              child: EmptyState(
                icon: Icons
                    .login_outlined,
                title:
                    'Sign in required',
                message:
                    'Sign in as a driver to save and select your vehicles.',
              ),
            )
          : StreamBuilder<
              DocumentSnapshot<
                  Map<String,
                      dynamic>>>(
              stream: AuthService()
                  .watchCurrentProfile(),
              builder: (
                context,
                profile,
              ) {
                return StreamBuilder<
                    List<Vehicle>>(
                  stream: vehicles,
                  builder: (
                    context,
                    snapshot,
                  ) {
                    if (snapshot
                        .hasError) {
                      final error =
                          snapshot.error;

                      final permissionDenied =
                          error is FirebaseException &&
                              error.code ==
                                  'permission-denied';

                      return EmptyState(
                        icon: Icons
                            .error_outline_rounded,
                        title:
                            'Unable to load vehicles',
                        message:
                            permissionDenied
                                ? 'Vehicle access was denied for this account. Contact support if this continues.'
                                : 'Check your connection and try again.',
                      );
                    }

                    if (!snapshot
                        .hasData) {
                      return const Center(
                        child:
                            CircularProgressIndicator(),
                      );
                    }

                    final items =
                        snapshot.data!;

                    final defaultId =
                        profile.data
                                ?.data()?[
                            'defaultVehicleId']
                            as String?;

                    return ListView(
                      padding:
                          const EdgeInsets
                              .fromLTRB(
                        RaSpace.lg,
                        RaSpace.md,
                        RaSpace.lg,
                        110,
                      ),
                      children: [
                        if (busy) ...[
                          const LinearProgressIndicator(
                            minHeight: 3,
                          ),
                          const SizedBox(
                            height:
                                RaSpace
                                    .md,
                          ),
                        ],

                        _header(
                          context,
                          items.length,
                        ),

                        const SizedBox(
                          height:
                              RaSpace.xl,
                        ),

                        if (items
                            .isEmpty)
                          _VehiclesEmptyState(
                            onAdd:
                                () =>
                                    edit(),
                          )
                        else
                          for (var index =
                                  0;
                              index <
                                  items.length;
                              index++) ...[
                            _vehicleCard(
                              context,
                              items[index],
                              defaultId ==
                                  items[index]
                                      .id,
                            ),
                            if (index !=
                                items.length -
                                    1)
                              const SizedBox(
                                height:
                                    RaSpace
                                        .sm,
                              ),
                          ],

                        if (widget
                            .selecting) ...[
                          const SizedBox(
                            height:
                                RaSpace.lg,
                          ),
                          OutlinedButton.icon(
                            onPressed:
                                busy
                                    ? null
                                    : () =>
                                        Navigator.pop(
                                      context,
                                    ),
                            icon: const Icon(
                              Icons
                                  .edit_road_outlined,
                            ),
                            label: const Text(
                              'Use Another Vehicle Without Saving',
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}

class _VehicleMetaChip
    extends StatelessWidget {
  const _VehicleMetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: colors
            .surfaceContainerHighest
            .withValues(alpha: .65),
        borderRadius:
            BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: colors
                .onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall,
          ),
        ],
      ),
    );
  }
}

class _VehiclesEmptyState
    extends StatelessWidget {
  const _VehiclesEmptyState({
    required this.onAdd,
  });

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        RaSpace.xl,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .6),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration:
                BoxDecoration(
              color: colors
                  .primaryContainer,
              borderRadius:
                  BorderRadius.circular(
                23,
              ),
            ),
            child: Icon(
              Icons
                  .directions_car_outlined,
              size: 34,
              color: colors
                  .onPrimaryContainer,
            ),
          ),
          const SizedBox(
            height: RaSpace.lg,
          ),
          Text(
            'No saved vehicles',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          const SizedBox(
            height: RaSpace.sm,
          ),
          Text(
            'Save your vehicle details once to make future assistance requests faster.',
            textAlign:
                TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium,
          ),
          const SizedBox(
            height: RaSpace.lg,
          ),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(
              Icons.add_rounded,
            ),
            label: const Text(
              'Add First Vehicle',
            ),
          ),
        ],
      ),
    );
  }
}