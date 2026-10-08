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
  final form =
      GlobalKey<FormState>();

  late final TextEditingController make;
  late final TextEditingController model;
  late final TextEditingController year;
  late final TextEditingController registration;

  String type =
      'Sedan / Hatchback';

  String fuel =
      'Petrol';

  String transmission =
      'Automatic';

  bool saving = false;
  bool uploadingPhoto = false;

  String photoData = '';

  bool get editing =>
      widget.vehicle != null;

  @override
  void initState() {
    super.initState();

    final vehicle =
        widget.vehicle;

    photoData =
        vehicle?.photoData ?? '';

    make = TextEditingController(
      text: vehicle?.make,
    );

    model = TextEditingController(
      text: vehicle?.model,
    );

    year = TextEditingController(
      text: vehicle?.year.toString(),
    );

    registration =
        TextEditingController(
      text:
          vehicle?.registration,
    );

    type =
        vehicle?.vehicleType ??
            type;

    fuel =
        vehicle?.fuelType ??
            fuel;

    transmission =
        vehicle?.transmission ??
            transmission;
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
    if (uploadingPhoto) {
      return;
    }

    setState(() {
      uploadingPhoto = true;
    });

    try {
      final photo =
          await ImagePicker().pickImage(
        source:
            ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 82,
      );

      if (photo == null) {
        return;
      }

      final encoded =
          await PhotoUploadService()
              .prepareVehiclePhoto(
        photo,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        photoData = encoded;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
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
    FocusScope.of(context)
        .unfocus();

    if (saving ||
        !(form.currentState
                ?.validate() ??
            false)) {
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      await VehicleService().save(
        Vehicle(
          id:
              widget.vehicle?.id ?? '',
          make:
              make.text.trim(),
          model:
              model.text.trim(),
          year: int.parse(
            year.text.trim(),
          ),
          vehicleType:
              type,
          registration:
              normalizeVehicleRegistration(
            registration.text,
          ),
          fuelType:
              fuel,
          transmission:
              transmission,
          photoData:
              photoData,
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not save vehicle: $error',
          ),
          backgroundColor:
              raDanger,
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
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final previewName = [
      make.text.trim(),
      model.text.trim(),
      year.text.trim(),
    ]
        .where(
          (value) =>
              value.isNotEmpty,
        )
        .join(' ');

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          editing
              ? 'Edit Vehicle'
              : 'Add Vehicle',
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
      body: Form(
        key: form,
        child: ListView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior
                  .onDrag,
          padding:
              const EdgeInsets.fromLTRB(
            18,
            8,
            18,
            120,
          ),
          children: [
            _RaVehicleEditorHero(
              editing:
                  editing,
            ),

            const SizedBox(height: 20),

            const _RaVehicleEditorHeading(
              title:
                  'Vehicle photo',
              subtitle:
                  'Optional. A clear exterior photo can help identify the vehicle.',
            ),

            const SizedBox(height: 10),

            _RaVehicleEditorSurface(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .stretch,
                children: [
                  VehiclePhotoPreview(
                    model:
                        previewName.isEmpty
                            ? 'Vehicle'
                            : previewName,
                    photoData:
                        photoData,
                    height: 180,
                    compact: false,
                  ),
                  const SizedBox(height: 11),
                  OutlinedButton.icon(
                    onPressed:
                        uploadingPhoto ||
                                saving
                            ? null
                            : addPhoto,
                    icon: uploadingPhoto
                        ? const SizedBox
                            .square(
                            dimension: 16,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                            ),
                          )
                        : const Icon(
                            Icons
                                .add_photo_alternate_outlined,
                          ),
                    label: Text(
                      photoData.isEmpty
                          ? 'Add Vehicle Photo'
                          : 'Change Photo',
                    ),
                  ),
                  if (photoData.isNotEmpty)
                    TextButton.icon(
                      onPressed:
                          saving
                              ? null
                              : () {
                                  setState(() {
                                    photoData =
                                        '';
                                  });
                                },
                      icon: const Icon(
                        Icons
                            .delete_outline_rounded,
                      ),
                      label: const Text(
                        'Remove Photo',
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            const _RaVehicleEditorHeading(
              title:
                  'Vehicle details',
              subtitle:
                  'Enter the information needed to identify your vehicle during roadside assistance.',
            ),

            const SizedBox(height: 10),

            _RaVehicleEditorSurface(
              child: Column(
                children: [
                  TextFormField(
                    controller: make,
                    enabled: !saving,
                    textCapitalization:
                        TextCapitalization.words,
                    textInputAction:
                        TextInputAction.next,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Vehicle make',
                      hintText:
                          'Toyota',
                      prefixIcon: Icon(
                        Icons
                            .branding_watermark_outlined,
                      ),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value
                              .trim()
                              .isEmpty) {
                        return 'Enter vehicle make';
                      }

                      return null;
                    },
                    onChanged: (_) {
                      setState(() {});
                    },
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller: model,
                    enabled: !saving,
                    textCapitalization:
                        TextCapitalization.words,
                    textInputAction:
                        TextInputAction.next,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Model',
                      hintText:
                          'Aqua',
                      prefixIcon: Icon(
                        Icons
                            .directions_car_outlined,
                      ),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value
                              .trim()
                              .isEmpty) {
                        return 'Enter vehicle model';
                      }

                      return null;
                    },
                    onChanged: (_) {
                      setState(() {});
                    },
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller: year,
                    enabled: !saving,
                    maxLength: 4,
                    keyboardType:
                        TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter
                          .digitsOnly,
                    ],
                    textInputAction:
                        TextInputAction.next,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Model year',
                      hintText:
                          '2018',
                      prefixIcon: Icon(
                        Icons
                            .calendar_month_outlined,
                      ),
                    ),
                    validator: (value) {
                      final number =
                          int.tryParse(
                        value?.trim() ?? '',
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
                    onChanged: (_) {
                      setState(() {});
                    },
                  ),

                  const SizedBox(height: 12),

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
                          'CAA-1234',
                      prefixIcon: Icon(
                        Icons
                            .pin_outlined,
                      ),
                    ),
                    validator:
                        validateVehicleRegistration,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            const _RaVehicleEditorHeading(
              title:
                  'Vehicle configuration',
              subtitle:
                  'These details can help providers prepare for your vehicle.',
            ),

            const SizedBox(height: 10),

            _RaVehicleEditorSurface(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .stretch,
                children: [
                  _RaVehicleChoice(
                    label:
                        'Vehicle type',
                    value:
                        type,
                    values: const [
                      'Sedan / Hatchback',
                      'SUV',
                      'Van',
                      'Motorcycle',
                      'Other',
                    ],
                    enabled:
                        !saving,
                    icon: Icons
                        .category_outlined,
                    onChanged:
                        (value) {
                      setState(() {
                        type = value;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  _RaVehicleChoice(
                    label:
                        'Fuel type',
                    value:
                        fuel,
                    values: const [
                      'Petrol',
                      'Diesel',
                      'Hybrid',
                      'Electric',
                      'Other',
                    ],
                    enabled:
                        !saving,
                    icon: Icons
                        .local_gas_station_outlined,
                    onChanged:
                        (value) {
                      setState(() {
                        fuel = value;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  _RaVehicleChoice(
                    label:
                        'Transmission',
                    value:
                        transmission,
                    values: const [
                      'Automatic',
                      'Manual',
                      'Other',
                    ],
                    enabled:
                        !saving,
                    icon:
                        Icons.settings_outlined,
                    onChanged:
                        (value) {
                      setState(() {
                        transmission =
                            value;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    saving ? null : save,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 17,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons
                            .check_rounded,
                      ),
                label: Text(
                  saving
                      ? 'Saving Vehicle…'
                      : editing
                          ? 'Save Vehicle Changes'
                          : 'Add Vehicle',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RaVehicleEditorHero
    extends StatelessWidget {
  const _RaVehicleEditorHero({
    required this.editing,
  });

  final bool editing;

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: dark
              ? const [
                  Color(0xFF0A497F),
                  Color(0xFF075A68),
                ]
              : const [
                  Color(0xFF075BA8),
                  Color(0xFF078C7E),
                ],
        ),
        borderRadius:
            BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          Container(
            width: 51,
            height: 51,
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withValues(alpha: .13),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons
                  .directions_car_filled_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  editing
                      ? 'Update your vehicle'
                      : 'Add a vehicle',
                  style: GoogleFonts
                      .plusJakartaSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Accurate vehicle details help make roadside requests faster and clearer.',
                  style: GoogleFonts
                      .plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 8.4,
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

class _RaVehicleEditorHeading
    extends StatelessWidget {
  const _RaVehicleEditorHeading({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 14.5,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 8.3,
            height: 1.4,
            color:
                colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RaVehicleEditorSurface
    extends StatelessWidget {
  const _RaVehicleEditorSurface({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.brightness ==
                Brightness.dark
            ? const Color(0xFF0D1D2B)
            : theme.colorScheme.surface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: theme
              .colorScheme
              .outlineVariant
              .withValues(
            alpha: .45,
          ),
        ),
      ),
      child: child,
    );
  }
}

class _RaVehicleChoice
    extends StatelessWidget {
  const _RaVehicleChoice({
    required this.label,
    required this.value,
    required this.values,
    required this.enabled,
    required this.icon,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final bool enabled;
  final IconData icon;
  final ValueChanged<String>
      onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      items: [
        for (final option
            in values)
          DropdownMenuItem<String>(
            value: option,
            child: Text(
              option,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: !enabled
          ? null
          : (selected) {
              if (selected != null) {
                onChanged(
                  selected,
                );
              }
            },
    );
  }
}