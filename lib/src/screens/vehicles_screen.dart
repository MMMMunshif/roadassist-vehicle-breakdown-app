part of '../screens.dart';

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

class VehicleEditorScreen extends StatefulWidget {
  const VehicleEditorScreen({super.key, this.vehicle});
  final Vehicle? vehicle;
  @override
  State<VehicleEditorScreen> createState() => _VehicleEditorScreenState();
}

class _VehicleEditorScreenState extends State<VehicleEditorScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController make, model, year, registration;
  String type = 'Sedan / Hatchback',
      fuel = 'Petrol',
      transmission = 'Automatic';
  bool saving = false;
  String photoData = '';
  bool uploadingPhoto = false;
  Future<void> addPhoto() async {
    setState(() => uploadingPhoto = true);
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
      );
      if (photo == null) return;
      final encoded = await PhotoUploadService().prepareVehiclePhoto(photo);
      if (mounted) setState(() => photoData = encoded);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load photo. Choose another image.'),
          ),
        );
    } finally {
      if (mounted) setState(() => uploadingPhoto = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    photoData = v?.photoData ?? '';
    make = TextEditingController(text: v?.make);
    model = TextEditingController(text: v?.model);
    year = TextEditingController(text: v?.year.toString());
    registration = TextEditingController(text: v?.registration);
    type = v?.vehicleType ?? type;
    fuel = v?.fuelType ?? fuel;
    transmission = v?.transmission ?? transmission;
  }

  @override
  void dispose() {
    make.dispose();
    model.dispose();
    year.dispose();
    registration.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await VehicleService().save(
        Vehicle(
          id: widget.vehicle?.id ?? '',
          make: make.text.trim(),
          model: model.text.trim(),
          year: int.parse(year.text.trim()),
          vehicleType: type,
          registration: normalizeVehicleRegistration(registration.text),
          fuelType: fuel,
          transmission: transmission,
          photoData: photoData,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save vehicle: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget choice(
    String label,
    String value,
    List<String> values,
    ValueChanged<String> changed,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: values
        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
        .toList(),
    onChanged: saving
        ? null
        : (v) {
            if (v != null) changed(v);
          },
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.vehicle == null ? 'Add Vehicle' : 'Edit Vehicle'),
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          VehiclePhotoPreview(
            model: '${make.text} ${model.text} ${year.text}',
            photoData: photoData,
          ),
          OutlinedButton.icon(
            onPressed: saving || uploadingPhoto ? null : addPhoto,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              uploadingPhoto ? 'Preparing photo...' : 'Add your vehicle photo',
            ),
          ),
          if (photoData.isNotEmpty)
            TextButton(
              onPressed: saving ? null : () => setState(() => photoData = ''),
              child: const Text('Remove saved photo / Use reference photo'),
            ),
          for (final entry in [('Make', make), ('Model', model)])
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextFormField(
                controller: entry.$2,
                onChanged: (_) => setState(() {}),
                enabled: !saving,
                maxLength: 40,
                decoration: InputDecoration(labelText: entry.$1),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Required' : null,
              ),
            ),
          TextFormField(
            controller: year,
            onChanged: (_) => setState(() {}),
            enabled: !saving,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Year'),
            validator: (v) {
              final n = int.tryParse(v?.trim() ?? '');
              return n == null || n < 1950 || n > DateTime.now().year + 1
                  ? 'Enter a valid vehicle year'
                  : null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: registration,
            enabled: !saving,
            maxLength: 16,
            decoration: const InputDecoration(labelText: 'Registration'),
            validator: validateVehicleRegistration,
          ),
          choice('Vehicle type', type, [
            'Sedan / Hatchback',
            'SUV',
            'Van',
            'Motorcycle',
            'Other',
          ], (v) => setState(() => type = v)),
          const SizedBox(height: 16),
          choice('Fuel type', fuel, [
            'Petrol',
            'Diesel',
            'Hybrid',
            'Electric',
            'Other',
          ], (v) => setState(() => fuel = v)),
          const SizedBox(height: 16),
          choice('Transmission', transmission, [
            'Automatic',
            'Manual',
            'Other',
          ], (v) => setState(() => transmission = v)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: saving || uploadingPhoto ? null : save,
            child: Text(saving ? 'Saving…' : 'Save Vehicle'),
          ),
        ],
      ),
    ),
  );
}
