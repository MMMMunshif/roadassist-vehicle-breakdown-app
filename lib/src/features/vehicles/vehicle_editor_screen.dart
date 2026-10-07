part of '../../screens.dart';

class VehicleEditorScreen extends StatefulWidget {
  const VehicleEditorScreen({
    super.key,
    this.vehicle,
  });

  final Vehicle? vehicle;

  @override
  State<VehicleEditorScreen> createState() =>
      _VehicleEditorScreenState();
}

class _VehicleEditorScreenState
    extends State<VehicleEditorScreen> {
  final form = GlobalKey<FormState>();

  late final TextEditingController make;
  late final TextEditingController model;
  late final TextEditingController year;
  late final TextEditingController registration;

  String type = 'Sedan / Hatchback';
  String fuel = 'Petrol';
  String transmission = 'Automatic';

  bool saving = false;
  bool uploadingPhoto = false;

  String photoData = '';

  bool get editing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();

    final vehicle = widget.vehicle;

    photoData = vehicle?.photoData ?? '';

    make = TextEditingController(
      text: vehicle?.make,
    );

    model = TextEditingController(
      text: vehicle?.model,
    );

    year = TextEditingController(
      text: vehicle?.year.toString(),
    );

    registration = TextEditingController(
      text: vehicle?.registration,
    );

    type = vehicle?.vehicleType ?? type;
    fuel = vehicle?.fuelType ?? fuel;
    transmission =
        vehicle?.transmission ?? transmission;
  }

  @override
  void dispose() {
    make.dispose();
    model.dispose();
    year.dispose();
    registration.dispose();
    super.dispose();
  }

  Future<void> addPhoto() async {
    if (uploadingPhoto) return;

    setState(() {
      uploadingPhoto = true;
    });

    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
      );

      if (photo == null) return;

      final encoded =
          await PhotoUploadService()
              .prepareVehiclePhoto(photo);

      if (!mounted) return;

      setState(() {
        photoData = encoded;
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not load the photo. Choose another image and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          uploadingPhoto = false;
        });
      }
    }
  }

  Future<void> save() async {
    FocusScope.of(context).unfocus();

    if (!(form.currentState?.validate() ?? false) ||
        saving) {
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      await VehicleService().save(
        Vehicle(
          id: widget.vehicle?.id ?? '',
          make: make.text.trim(),
          model: model.text.trim(),
          year: int.parse(
            year.text.trim(),
          ),
          vehicleType: type,
          registration:
              normalizeVehicleRegistration(
            registration.text,
          ),
          fuelType: fuel,
          transmission: transmission,
          photoData: photoData,
        ),
      );

      if (!mounted) return;

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save vehicle: $error',
          ),
          backgroundColor: raDanger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final vehicleName = [
      make.text.trim(),
      model.text.trim(),
      year.text.trim(),
    ].where((value) => value.isNotEmpty).join(' ');

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          editing
              ? 'Edit Vehicle'
              : 'Add Vehicle',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: form,
          child: ListView(
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior
                    .onDrag,
            padding:
                const EdgeInsets.fromLTRB(
              RaSpace.lg,
              RaSpace.md,
              RaSpace.lg,
              120,
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(
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
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withValues(
                          alpha: .14,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                      ),
                      child: const Icon(
                        Icons
                            .directions_car_filled_outlined,
                        color: Colors.white,
                        size: 29,
                      ),
                    ),
                    const SizedBox(
                      width: RaSpace.lg,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            editing
                                ? 'Update vehicle details'
                                : 'Add a vehicle',
                            style: theme
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                              color: Colors.white,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            'Accurate vehicle information helps providers prepare for your roadside request.',
                            style: theme
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color: Colors.white
                                  .withValues(
                                alpha: .82,
                              ),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: RaSpace.xl,
              ),

              _VehicleEditorSection(
                title: 'Vehicle photo',
                description:
                    'Add a clear photo to make your vehicle easier to identify.',
                icon:
                    Icons.photo_camera_outlined,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                      child:
                          VehiclePhotoPreview(
                        model:
                            vehicleName.isEmpty
                            ? 'Your vehicle'
                            : vehicleName,
                        photoData:
                            photoData,
                      ),
                    ),

                    const SizedBox(
                      height: RaSpace.md,
                    ),

                    OutlinedButton.icon(
                      onPressed:
                          saving ||
                              uploadingPhoto
                          ? null
                          : addPhoto,
                      icon: uploadingPhoto
                          ? const SizedBox.square(
                              dimension: 17,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .add_photo_alternate_outlined,
                            ),
                      label: Text(
                        uploadingPhoto
                            ? 'Preparing Photo…'
                            : photoData.isEmpty
                            ? 'Add Vehicle Photo'
                            : 'Change Vehicle Photo',
                      ),
                    ),

                    if (photoData
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: RaSpace.xs,
                      ),
                      TextButton.icon(
                        onPressed: saving
                            ? null
                            : () {
                                setState(() {
                                  photoData = '';
                                });
                              },
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                        ),
                        label: const Text(
                          'Remove Saved Photo',
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(
                height: RaSpace.md,
              ),

              _VehicleEditorSection(
                title: 'Vehicle identity',
                description:
                    'Enter the basic details shown on your vehicle documents.',
                icon:
                    Icons.badge_outlined,
                child: Column(
                  children: [
                    TextFormField(
                      controller: make,
                      enabled: !saving,
                      maxLength: 40,
                      textCapitalization:
                          TextCapitalization.words,
                      textInputAction:
                          TextInputAction.next,
                      onChanged: (_) {
                        setState(() {});
                      },
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Vehicle make',
                        hintText:
                            'e.g. Toyota',
                        prefixIcon: Icon(
                          Icons
                              .factory_outlined,
                        ),
                      ),
                      validator: (value) =>
                          value?.trim().isEmpty ??
                                  true
                              ? 'Enter vehicle make'
                              : null,
                    ),

                    const SizedBox(
                      height: RaSpace.md,
                    ),

                    TextFormField(
                      controller: model,
                      enabled: !saving,
                      maxLength: 40,
                      textCapitalization:
                          TextCapitalization.words,
                      textInputAction:
                          TextInputAction.next,
                      onChanged: (_) {
                        setState(() {});
                      },
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Vehicle model',
                        hintText:
                            'e.g. Corolla',
                        prefixIcon: Icon(
                          Icons
                              .directions_car_outlined,
                        ),
                      ),
                      validator: (value) =>
                          value?.trim().isEmpty ??
                                  true
                              ? 'Enter vehicle model'
                              : null,
                    ),

                    const SizedBox(
                      height: RaSpace.md,
                    ),

                    TextFormField(
                      controller: year,
                      enabled: !saving,
                      keyboardType:
                          TextInputType.number,
                      textInputAction:
                          TextInputAction.next,
                      onChanged: (_) {
                        setState(() {});
                      },
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Manufacture year',
                        hintText: 'e.g. 2022',
                        prefixIcon: Icon(
                          Icons
                              .calendar_today_outlined,
                        ),
                      ),
                      validator: (value) {
                        final number =
                            int.tryParse(
                          value?.trim() ??
                              '',
                        );

                        if (number == null ||
                            number < 1950 ||
                            number >
                                DateTime.now()
                                        .year +
                                    1) {
                          return 'Enter a valid vehicle year';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: RaSpace.md,
                    ),

                    TextFormField(
                      controller:
                          registration,
                      enabled: !saving,
                      maxLength: 16,
                      textCapitalization:
                          TextCapitalization
                              .characters,
                      textInputAction:
                          TextInputAction.done,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Registration number',
                        hintText:
                            'e.g. WP ABC 1234',
                        prefixIcon: Icon(
                          Icons
                              .confirmation_number_outlined,
                        ),
                      ),
                      validator:
                          validateVehicleRegistration,
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: RaSpace.md,
              ),

              _VehicleEditorSection(
                title: 'Vehicle specifications',
                description:
                    'These details can help providers bring suitable tools and equipment.',
                icon:
                    Icons.tune_outlined,
                child: Column(
                  children: [
                    _VehicleEditorChoice(
                      label: 'Vehicle type',
                      icon: Icons
                          .directions_car_outlined,
                      value: type,
                      values: const [
                        'Sedan / Hatchback',
                        'SUV',
                        'Van',
                        'Motorcycle',
                        'Other',
                      ],
                      enabled: !saving,
                      onChanged: (value) {
                        setState(() {
                          type = value;
                        });
                      },
                    ),

                    const SizedBox(
                      height: RaSpace.md,
                    ),

                    _VehicleEditorChoice(
                      label: 'Fuel type',
                      icon:
                          Icons.local_gas_station_outlined,
                      value: fuel,
                      values: const [
                        'Petrol',
                        'Diesel',
                        'Hybrid',
                        'Electric',
                        'Other',
                      ],
                      enabled: !saving,
                      onChanged: (value) {
                        setState(() {
                          fuel = value;
                        });
                      },
                    ),

                    const SizedBox(
                      height: RaSpace.md,
                    ),

                    _VehicleEditorChoice(
                      label: 'Transmission',
                      icon: Icons
                          .settings_input_component_outlined,
                      value: transmission,
                      values: const [
                        'Automatic',
                        'Manual',
                        'Other',
                      ],
                      enabled: !saving,
                      onChanged: (value) {
                        setState(() {
                          transmission =
                              value;
                        });
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: RaSpace.md,
              ),

              Container(
                padding: const EdgeInsets.all(
                  RaSpace.md,
                ),
                decoration: BoxDecoration(
                  color: colors
                      .surfaceContainerHighest
                      .withValues(alpha: .34),
                  borderRadius:
                      BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons
                          .verified_user_outlined,
                      size: 19,
                      color: colors.primary,
                    ),
                    const SizedBox(
                      width: RaSpace.sm,
                    ),
                    Expanded(
                      child: Text(
                        'Vehicle details are used to match your request with suitable roadside service providers.',
                        style: theme
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          height: 1.4,
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            RaSpace.lg,
            RaSpace.sm,
            RaSpace.lg,
            RaSpace.md,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(
              top: BorderSide(
                color: colors.outlineVariant
                    .withValues(alpha: .55),
              ),
            ),
          ),
          child: FilledButton.icon(
            onPressed:
                saving || uploadingPhoto
                ? null
                : save,
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    editing
                        ? Icons
                            .save_outlined
                        : Icons
                            .add_circle_outline,
                  ),
            label: Text(
              saving
                  ? 'Saving Vehicle…'
                  : editing
                  ? 'Save Changes'
                  : 'Add Vehicle',
            ),
          ),
        ),
      ),
    );
  }
}

class _VehicleEditorSection
    extends StatelessWidget {
  const _VehicleEditorSection({
    required this.title,
    required this.description,
    required this.icon,
    required this.child,
  });

  final String title;
  final String description;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(
        RaSpace.lg,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .55),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color:
                      colors.primaryContainer,
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color:
                      colors.onPrimaryContainer,
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
                    Text(
                      title,
                      style: theme
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      description,
                      style: theme
                          .textTheme.bodySmall
                          ?.copyWith(
                        color: colors
                            .onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: RaSpace.lg,
          ),
          child,
        ],
      ),
    );
  }
}

class _VehicleEditorChoice
    extends StatelessWidget {
  const _VehicleEditorChoice({
    required this.label,
    required this.icon,
    required this.value,
    required this.values,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final String value;
  final List<String> values;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      items: values
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item),
            ),
          )
          .toList(),
      onChanged: !enabled
          ? null
          : (selected) {
              if (selected != null) {
                onChanged(selected);
              }
            },
    );
  }
}