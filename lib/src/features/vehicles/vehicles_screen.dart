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
    setState(() => busy = true);
    try {
      await work();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not update vehicle: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void edit([Vehicle? vehicle]) =>
      push(context, VehicleEditorScreen(vehicle: vehicle));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.selecting ? 'Which vehicle needs help?' : 'My Vehicles',
      ),
    ),
    body: !signedIn
        ? const Center(child: Text('Sign in to save and select your vehicles.'))
        : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: AuthService().watchCurrentProfile(),
            builder: (context, profile) => StreamBuilder<List<Vehicle>>(
              stream: vehicles,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  final permissionDenied =
                      error is FirebaseException &&
                      error.code == 'permission-denied';
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 40),
                          const SizedBox(height: 16),
                          Text(
                            permissionDenied
                                ? 'Vehicle access was denied. Your driver account needs access to saved vehicles. Please contact support if this continues.'
                                : 'Could not load vehicles. Check your connection and try again.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => setState(() {
                              vehicles = service.watchVehicles();
                            }),
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final items = snapshot.data!;
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (busy) const LinearProgressIndicator(),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Save your vehicle once to reuse its details on future requests.',
                        ),
                      ),
                    for (final v in items)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.directions_car),
                          title: Text(v.label),
                          subtitle: Text(
                            '${v.registration} • ${v.fuelType}\n${v.transmission}${profile.data?.data()?['defaultVehicleId'] == v.id ? ' • Default' : ''}',
                          ),
                          onTap: busy
                              ? null
                              : () => widget.selecting
                                    ? Navigator.pop(context, v)
                                    : edit(v),
                          trailing: PopupMenuButton<String>(
                            enabled: !busy,
                            onSelected: (value) async {
                              if (value == 'edit') {
                                edit(v);
                                return;
                              }
                              if (value == 'default') {
                                await action(() => service.setDefault(v.id));
                                return;
                              }
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Archive vehicle?'),
                                  content: const Text(
                                    'It will be removed from your list. Existing request history will remain.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Keep'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Archive'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true && mounted)
                                await action(() => service.archive(v.id));
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'default',
                                child: Text('Set default'),
                              ),
                              PopupMenuItem(
                                value: 'archive',
                                child: Text('Archive'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: busy ? null : () => edit(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Vehicle'),
                    ),
                    if (widget.selecting)
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Use another vehicle without saving'),
                      ),
                  ],
                );
              },
            ),
          ),
  );
}
