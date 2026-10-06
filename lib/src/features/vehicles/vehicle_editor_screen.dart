part of '../../screens.dart';

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
