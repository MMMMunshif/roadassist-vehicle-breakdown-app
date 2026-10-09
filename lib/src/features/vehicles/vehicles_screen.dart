part of '../../screens.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key, this.selecting = false});

  final bool selecting;

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
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

  Future<void> action(Future<void> Function() work) async {
    if (busy) {
      return;
    }

    setState(() {
      busy = true;
    });

    try {
      await work();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update vehicle: $error')),
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
    push(context, VehicleEditorScreen(vehicle: vehicle));
  }

  Future<void> archiveVehicle(Vehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          icon: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.error.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(Icons.archive_outlined, color: colors.error),
          ),
          title: const Text('Archive this vehicle?'),
          content: const Text(
            'It will be removed from your saved vehicle list. Existing assistance history will remain unchanged.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Keep Vehicle'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Archive'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await action(() => service.archive(vehicle.id));
  }

  Widget vehicleCard(Vehicle vehicle, bool isDefault) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final title = [
      vehicle.make,
      vehicle.model,
      '${vehicle.year}',
    ].where((value) => value.trim().isNotEmpty).join(' ');

    return Material(
      color: theme.brightness == Brightness.dark
          ? const Color(0xFF0D2237)
          : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDefault
              ? colors.primary.withValues(alpha: .40)
              : colors.outlineVariant.withValues(alpha: .45),
          width: isDefault ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy
            ? null
            : () {
                if (widget.selecting) {
                  Navigator.pop(context, vehicle);
                } else {
                  edit(vehicle);
                }
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                VehiclePhotoPreview(
                  model: title,
                  photoData: vehicle.photoData,
                  height: 155,
                  compact: false,
                ),
                if (isDefault)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'DEFAULT',
                        style: GoogleFonts.plusJakartaSans(
                          color: colors.onPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .6,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.isEmpty ? 'Saved vehicle' : title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              vehicle.registration,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!widget.selecting)
                        PopupMenuButton<String>(
                          tooltip: 'Vehicle options',
                          enabled: !busy,
                          onSelected: (value) async {
                            if (value == 'edit') {
                              edit(vehicle);
                            }

                            if (value == 'default') {
                              await action(
                                () => service.setDefault(vehicle.id),
                              );
                            }

                            if (value == 'archive') {
                              await archiveVehicle(vehicle);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.edit_outlined),
                                title: Text('Edit'),
                              ),
                            ),
                            if (!isDefault)
                              const PopupMenuItem(
                                value: 'default',
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.star_outline_rounded),
                                  title: Text('Set as default'),
                                ),
                              ),
                            const PopupMenuItem(
                              value: 'archive',
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.archive_outlined),
                                title: Text('Archive'),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _RaVehicleChip(
                        icon: Icons.directions_car_outlined,
                        text: vehicle.vehicleType,
                      ),
                      _RaVehicleChip(
                        icon: Icons.local_gas_station_outlined,
                        text: vehicle.fuelType,
                      ),
                      _RaVehicleChip(
                        icon: Icons.settings_outlined,
                        text: vehicle.transmission,
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Divider(
                    height: 1,
                    color: colors.outlineVariant.withValues(alpha: .35),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        widget.selecting
                            ? Icons.touch_app_outlined
                            : Icons.edit_outlined,
                        size: 14,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.selecting
                              ? 'Tap to use this vehicle'
                              : 'Tap to edit vehicle details',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!signedIn) {
      return RaDriverScaffold(
        appBar: AppBar(
          title: RaDriverAppBarTitle(
            widget.selecting ? 'Choose Vehicle' : 'My Vehicles',
          ),
        ),
        body: const Padding(
          padding: EdgeInsets.all(18),
          child: EmptyState(
            icon: Icons.login_outlined,
            title: 'Sign in required',
            message: 'Sign in to manage your saved vehicles.',
          ),
        ),
      );
    }

    return RaDriverScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: RaDriverAppBarTitle(
          widget.selecting ? 'Choose Vehicle' : 'My Vehicles',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButton: !widget.selecting
          ? FloatingActionButton.extended(
              onPressed: busy ? null : () => edit(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Vehicle'),
            )
          : null,
      body: StreamBuilder<List<Vehicle>>(
        stream: vehicles,
        builder: (context, vehicleSnapshot) {
          if (vehicleSnapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.all(18),
              child: EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Unable to load vehicles',
                message: 'Check your connection and try again.',
              ),
            );
          }

          if (!vehicleSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = vehicleSnapshot.data!;

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: AuthService().watchCurrentProfile(),
            builder: (context, profile) {
              final defaultId =
                  profile.data?.data()?['defaultVehicleId'] as String?;

              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
                children: [
                  _RaVehiclesHero(
                    count: items.length,
                    selecting: widget.selecting,
                  ),
                  const SizedBox(height: 19),
                  if (busy) ...[
                    const LinearProgressIndicator(minHeight: 3),
                    const SizedBox(height: 12),
                  ],
                  if (items.isEmpty)
                    _RaVehiclesEmpty(
                      selecting: widget.selecting,
                      onAdd: widget.selecting ? null : () => edit(),
                    )
                  else
                    for (var index = 0; index < items.length; index++) ...[
                      vehicleCard(items[index], defaultId == items[index].id),
                      if (index != items.length - 1) const SizedBox(height: 10),
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
  const _RaVehiclesHero({required this.count, required this.selecting});

  final int count;
  final bool selecting;

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
            width: 51,
            height: 51,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.directions_car_outlined,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selecting ? 'Which vehicle needs help?' : 'Your vehicles',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selecting
                      ? 'Select a saved vehicle to fill request details automatically.'
                      : count == 0
                      ? 'Save a vehicle once and reuse it when requesting roadside assistance.'
                      : '$count saved ${count == 1 ? 'vehicle' : 'vehicles'} ready for roadside requests.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 12,
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
}

class _RaVehicleChip extends StatelessWidget {
  const _RaVehicleChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colors.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaVehiclesEmpty extends StatelessWidget {
  const _RaVehiclesEmpty({required this.selecting, required this.onAdd});

  final bool selecting;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        EmptyState(
          icon: Icons.directions_car_outlined,
          title: 'No saved vehicles',
          message: selecting
              ? 'Add a vehicle from your profile before selecting one for this request.'
              : 'Add your first vehicle so RoadAssist can reuse its details during future requests.',
        ),
        if (onAdd != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add First Vehicle'),
            ),
          ),
        ],
      ],
    );
  }
}
