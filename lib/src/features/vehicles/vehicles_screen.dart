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

class _VehiclesScreenState
    extends State<VehiclesScreen> {
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
    if (busy) return;

    setState(() {
      busy = true;
    });

    try {
      await work();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
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
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colors.error
                  .withValues(alpha: .10),
              borderRadius:
                  BorderRadius.circular(
                17,
              ),
            ),
            child: Icon(
              Icons.archive_outlined,
              color: colors.error,
            ),
          ),
          title: const Text(
            'Archive this vehicle?',
          ),
          content: const Text(
            'It will be removed from your saved vehicles. Existing assistance history will remain unchanged.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
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
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.selecting
              ? 'Choose Vehicle'
              : 'My Vehicles',
          style: GoogleFonts
              .plusJakartaSans(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
      ),
      floatingActionButton:
          signedIn &&
                  !widget.selecting
              ? FloatingActionButton
                  .extended(
                  onPressed:
                      busy ? null : edit,
                  icon: const Icon(
                    Icons.add_rounded,
                  ),
                  label: const Text(
                    'Add Vehicle',
                  ),
                )
              : null,
      body: !signedIn
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyState(
                icon: Icons.login_outlined,
                title: 'Sign in required',
                message:
                    'Sign in as a driver to save and select your vehicles.',
              ),
            )
          : StreamBuilder<
              DocumentSnapshot<
                  Map<String, dynamic>>>(
              stream: AuthService()
                  .watchCurrentProfile(),
              builder:
                  (context, profile) {
                return StreamBuilder<
                    List<Vehicle>>(
                  stream: vehicles,
                  builder:
                      (context, snapshot) {
                    if (snapshot.hasError) {
                      final error =
                          snapshot.error;

                      final denied =
                          error is FirebaseException &&
                              error.code ==
                                  'permission-denied';

                      return EmptyState(
                        icon: Icons
                            .error_outline_rounded,
                        title:
                            'Unable to load vehicles',
                        message: denied
                            ? 'Vehicle access was denied for this account. Contact support if this continues.'
                            : 'Check your connection and try again.',
                      );
                    }

                    if (!snapshot.hasData) {
                      return const _RaVehiclesLoading();
                    }

                    final items =
                        snapshot.data!;

                    final defaultId =
                        profile.data
                                ?.data()?[
                            'defaultVehicleId']
                            as String?;

                    return ListView(
                      physics:
                          const BouncingScrollPhysics(),
                      padding:
                          const EdgeInsets.fromLTRB(
                        18,
                        8,
                        18,
                        110,
                      ),
                      children: [
                        if (busy) ...[
                          const LinearProgressIndicator(
                            minHeight: 3,
                          ),
                          const SizedBox(
                            height: 11,
                          ),
                        ],

                        _RaVehiclesHero(
                          count:
                              items.length,
                          selecting:
                              widget.selecting,
                        ),

                        const SizedBox(
                          height: 25,
                        ),

                        if (items.isEmpty)
                          _RaVehiclesEmpty(
                            onAdd: edit,
                          )
                        else ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.selecting
                                      ? 'Select vehicle'
                                      : 'Saved vehicles',
                                  style: GoogleFonts
                                      .plusJakartaSans(
                                    fontSize:
                                        17,
                                    fontWeight:
                                        FontWeight
                                            .w800,
                                    letterSpacing:
                                        -.35,
                                    color: theme
                                        .colorScheme
                                        .onSurface,
                                  ),
                                ),
                              ),

                              Text(
                                '${items.length}',
                                style: GoogleFonts
                                    .plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                  color: theme
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 11,
                          ),

                          for (var index =
                                  0;
                              index <
                                  items.length;
                              index++) ...[
                            _RaVehicleCard(
                              vehicle:
                                  items[index],
                              isDefault:
                                  defaultId ==
                                      items[
                                              index]
                                          .id,
                              selecting:
                                  widget
                                      .selecting,
                              busy: busy,
                              onOpen: () {
                                if (busy) {
                                  return;
                                }

                                if (widget
                                    .selecting) {
                                  Navigator.pop(
                                    context,
                                    items[
                                        index],
                                  );
                                } else {
                                  edit(
                                    items[
                                        index],
                                  );
                                }
                              },
                              onEdit: () {
                                edit(
                                  items[
                                      index],
                                );
                              },
                              onDefault:
                                  () async {
                                await action(
                                  () => service
                                      .setDefault(
                                    items[
                                            index]
                                        .id,
                                  ),
                                );
                              },
                              onArchive:
                                  () async {
                                await archiveVehicle(
                                  items[
                                      index],
                                );
                              },
                            ),

                            if (index !=
                                items.length -
                                    1)
                              const SizedBox(
                                height: 10,
                              ),
                          ],
                        ],

                        if (widget
                            .selecting) ...[
                          const SizedBox(
                            height: 18,
                          ),

                          OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () {
                                    Navigator.pop(
                                      context,
                                    );
                                  },
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

class _RaVehiclesHero extends StatelessWidget {
  const _RaVehiclesHero({
    required this.count,
    required this.selecting,
  });

  final int count;
  final bool selecting;

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: dark
              ? const [
                  Color(0xFF0B477C),
                  Color(0xFF08645D),
                ]
              : const [
                  Color(0xFF075BA8),
                  Color(0xFF078C7E),
                ],
        ),
        borderRadius:
            BorderRadius.circular(25),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            bottom: -31,
            child: Icon(
              Icons
                  .directions_car_filled_outlined,
              size: 130,
              color: Colors.white
                  .withValues(alpha: .06),
            ),
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha: .13,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                child: const Icon(
                  Icons.garage_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),

              const SizedBox(height: 15),

              Text(
                selecting
                    ? 'Which vehicle needs help?'
                    : 'Your garage',
                style: GoogleFonts
                    .plusJakartaSans(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing: -.5,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                selecting
                    ? 'Choose a saved vehicle and RoadAssist will fill its details into your request.'
                    : count == 0
                        ? 'Save your vehicle once to make future roadside requests faster.'
                        : '$count saved ${count == 1 ? 'vehicle' : 'vehicles'} ready for roadside assistance.',
                style: GoogleFonts
                    .plusJakartaSans(
                  color: Colors.white
                      .withValues(
                    alpha: .80,
                  ),
                  fontSize: 10.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RaVehicleCard extends StatelessWidget {
  const _RaVehicleCard({
    required this.vehicle,
    required this.isDefault,
    required this.selecting,
    required this.busy,
    required this.onOpen,
    required this.onEdit,
    required this.onDefault,
    required this.onArchive,
  });

  final Vehicle vehicle;
  final bool isDefault;
  final bool selecting;
  final bool busy;

  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final Future<void> Function()
      onDefault;

  final Future<void> Function()
      onArchive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final dark =
        theme.brightness == Brightness.dark;

    return Material(
      color: dark
          ? const Color(0xFF0D1D2B)
          : Colors.white,
      borderRadius:
          BorderRadius.circular(21),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onOpen,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(21),
            border: Border.all(
              color: isDefault
                  ? colors.primary
                      .withValues(
                      alpha: .38,
                    )
                  : colors.outlineVariant
                      .withValues(
                      alpha: .48,
                    ),
              width:
                  isDefault ? 1.3 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 88,
                    height: 67,
                    clipBehavior:
                        Clip.antiAlias,
                    decoration:
                        BoxDecoration(
                      color: colors
                          .surfaceContainerHighest
                          .withValues(
                        alpha: .50,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(15),
                    ),
                    child:
                        VehiclePhotoPreview(
                      model:
                          vehicle.label,
                      photoData:
                          vehicle.photoData,
                      height: 67,
                      compact: true,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${vehicle.make} ${vehicle.model}',
                                maxLines: 1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style: GoogleFonts
                                    .plusJakartaSans(
                                  fontSize:
                                      13,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                  color: colors
                                      .onSurface,
                                ),
                              ),
                            ),

                            if (isDefault)
                              Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal:
                                      7,
                                  vertical: 4,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color: colors
                                      .primary
                                      .withValues(
                                    alpha: .09,
                                  ),
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    999,
                                  ),
                                ),
                                child: Text(
                                  'DEFAULT',
                                  style: GoogleFonts
                                      .plusJakartaSans(
                                    color: colors
                                        .primary,
                                    fontSize:
                                        7.5,
                                    letterSpacing:
                                        .6,
                                    fontWeight:
                                        FontWeight
                                            .w700,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(
                          height: 4,
                        ),

                        Text(
                          '${vehicle.year} • ${vehicle.vehicleType}',
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style: GoogleFonts
                              .plusJakartaSans(
                            fontSize: 9.5,
                            color: colors
                                .onSurfaceVariant,
                          ),
                        ),

                        const SizedBox(
                          height: 7,
                        ),

                        Text(
                          vehicle.registration,
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style: GoogleFonts
                              .plusJakartaSans(
                            fontSize: 10.5,
                            letterSpacing:
                                .35,
                            fontWeight:
                                FontWeight
                                    .w700,
                            color:
                                colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 13),

              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _RaVehicleMeta(
                    icon: Icons
                        .local_gas_station_outlined,
                    label:
                        vehicle.fuelType,
                  ),
                  _RaVehicleMeta(
                    icon:
                        Icons.settings_outlined,
                    label:
                        vehicle.transmission,
                  ),
                ],
              ),

              const SizedBox(height: 13),

              Divider(
                height: 1,
                color: colors.outlineVariant
                    .withValues(
                  alpha: .35,
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      selecting
                          ? 'Tap to use this vehicle'
                          : isDefault
                              ? 'Primary roadside vehicle'
                              : 'Saved vehicle',
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 9.5,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ),

                  if (selecting)
                    Icon(
                      Icons
                          .arrow_forward_rounded,
                      size: 18,
                      color:
                          colors.primary,
                    )
                  else
                    PopupMenuButton<
                        String>(
                      enabled: !busy,
                      tooltip:
                          'Vehicle options',
                      onSelected:
                          (value) async {
                        if (value ==
                            'edit') {
                          onEdit();
                        } else if (value ==
                            'default') {
                          await onDefault();
                        } else if (value ==
                            'archive') {
                          await onArchive();
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
                              'Edit Vehicle',
                            ),
                          ),
                        ),
                        if (!isDefault)
                          const PopupMenuItem(
                            value:
                                'default',
                            child: ListTile(
                              contentPadding:
                                  EdgeInsets
                                      .zero,
                              leading: Icon(
                                Icons
                                    .star_outline_rounded,
                              ),
                              title: Text(
                                'Set as Default',
                              ),
                            ),
                          ),
                        const PopupMenuItem(
                          value:
                              'archive',
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
}

class _RaVehicleMeta extends StatelessWidget {
  const _RaVehicleMeta({
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
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: colors
            .surfaceContainerHighest
            .withValues(alpha: .46),
        borderRadius:
            BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color:
                colors.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 8.5,
              fontWeight:
                  FontWeight.w500,
              color: colors
                  .onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaVehiclesEmpty
    extends StatelessWidget {
  const _RaVehiclesEmpty({
    required this.onAdd,
  });

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(23),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .50),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: colors.primary
                  .withValues(alpha: .08),
              borderRadius:
                  BorderRadius.circular(21),
            ),
            child: Icon(
              Icons
                  .directions_car_outlined,
              size: 31,
              color: colors.primary,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'No saved vehicles',
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            'Save your vehicle details once and RoadAssist can reuse them in future assistance requests.',
            textAlign: TextAlign.center,
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              height: 1.45,
              color:
                  colors.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 17),

          FilledButton.icon(
            onPressed: onAdd,
            icon:
                const Icon(Icons.add_rounded),
            label: const Text(
              'Add First Vehicle',
            ),
          ),
        ],
      ),
    );
  }
}

class _RaVehiclesLoading
    extends StatelessWidget {
  const _RaVehiclesLoading();

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return ListView(
      padding:
          const EdgeInsets.all(18),
      children: [
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: colors
                .surfaceContainerHighest,
            borderRadius:
                BorderRadius.circular(25),
          ),
        ),

        const SizedBox(height: 24),

        for (var i = 0;
            i < 3;
            i++) ...[
          Container(
            height: 184,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius:
                  BorderRadius.circular(21),
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