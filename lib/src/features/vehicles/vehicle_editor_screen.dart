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

  String get vehiclePreviewName {
    return [
      make.text.trim(),
      model.text.trim(),
      year.text.trim(),
    ]
        .where((value) => value.isNotEmpty)
        .join(' ');
  }

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

  Future<void> choosePhoto() async {
    if (uploadingPhoto) return;

    final source =
        await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colors = theme.colorScheme;
        final dark =
            theme.brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.fromLTRB(
            18,
            12,
            18,
            24,
          ),
          decoration: BoxDecoration(
            color: dark
                ? const Color(0xFF0D1D2B)
                : colors.surface,
            borderRadius:
                const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors
                        .onSurfaceVariant
                        .withValues(alpha: .24),
                    borderRadius:
                        BorderRadius.circular(999),
                  ),
                ),
              ),

              const SizedBox(height: 21),

              Text(
                'Vehicle photo',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                  color: colors.onSurface,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                'Add a clear photo so your vehicle is easier to identify.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  height: 1.4,
                  color: colors.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 17),

              _RaVehiclePhotoSource(
                icon:
                    Icons.photo_library_outlined,
                title: 'Choose from gallery',
                subtitle:
                    'Use an existing vehicle photo',
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                    ImageSource.gallery,
                  );
                },
              ),

              const SizedBox(height: 9),

              _RaVehiclePhotoSource(
                icon:
                    Icons.camera_alt_outlined,
                title: 'Take a photo',
                subtitle:
                    'Capture your vehicle now',
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                    ImageSource.camera,
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    if (source == null || !mounted) return;

    setState(() {
      uploadingPhoto = true;
    });

    try {
      final navigator =
          Navigator.of(context);

      final photo = source == ImageSource.camera
          ? await navigator.push<XFile>(
              MaterialPageRoute(
                builder: (_) =>
                    const CameraCaptureScreen(),
              ),
            )
          : await ImagePicker().pickImage(
              source: ImageSource.gallery,
              imageQuality: 80,
              maxWidth: 1200,
            );

      if (photo == null || !mounted) return;

      final encoded =
          await PhotoUploadService()
              .prepareVehiclePhoto(photo);

      if (!mounted) return;

      setState(() {
        photoData = encoded;
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Could not prepare the photo. Choose another image and try again.',
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

    if (!(form.currentState?.validate() ??
            false) ||
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

      ScaffoldMessenger.of(context)
          .showSnackBar(
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

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          editing
              ? 'Edit Vehicle'
              : 'Add Vehicle',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
      ),
      body: Form(
        key: form,
        child: ListView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior
                  .onDrag,
          physics:
              const BouncingScrollPhysics(),
          padding:
              const EdgeInsets.fromLTRB(
            18,
            8,
            18,
            120,
          ),
          children: [
            _RaVehicleEditorHero(
              editing: editing,
            ),

            const SizedBox(height: 18),

            _RaVehicleEditorSection(
              icon:
                  Icons.photo_camera_outlined,
              title: 'Vehicle photo',
              subtitle:
                  'Make the vehicle easier for a provider to recognize.',
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: colors
                          .surfaceContainerHighest
                          .withValues(alpha: .40),
                      borderRadius:
                          BorderRadius.circular(18),
                    ),
                    child: VehiclePhotoPreview(
                      model:
                          vehiclePreviewName.isEmpty
                              ? 'Your vehicle'
                              : vehiclePreviewName,
                      photoData: photoData,
                      height: 190,
                    ),
                  ),

                  const SizedBox(height: 12),

                  FilledButton.tonalIcon(
                    onPressed: saving ||
                            uploadingPhoto
                        ? null
                        : choosePhoto,
                    icon: uploadingPhoto
                        ? const SizedBox.square(
                            dimension: 17,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            photoData.isEmpty
                                ? Icons
                                    .add_a_photo_outlined
                                : Icons
                                    .photo_camera_outlined,
                          ),
                    label: Text(
                      uploadingPhoto
                          ? 'Preparing photo…'
                          : photoData.isEmpty
                              ? 'Add Vehicle Photo'
                              : 'Change Vehicle Photo',
                    ),
                  ),

                  if (photoData.isNotEmpty) ...[
                    const SizedBox(height: 8),

                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor:
                            colors.error,
                      ),
                      onPressed: saving ||
                              uploadingPhoto
                          ? null
                          : () {
                              setState(() {
                                photoData = '';
                              });
                            },
                      icon: const Icon(
                        Icons
                            .delete_outline_rounded,
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

            const SizedBox(height: 12),

            _RaVehicleEditorSection(
              icon: Icons.badge_outlined,
              title: 'Vehicle identity',
              subtitle:
                  'Enter the information shown on your vehicle documents.',
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
                      labelText: 'Vehicle make',
                      hintText: 'e.g. Toyota',
                      prefixIcon: Icon(
                        Icons.factory_outlined,
                      ),
                    ),
                    validator: (value) {
                      return value
                                  ?.trim()
                                  .isEmpty ??
                              true
                          ? 'Enter vehicle make'
                          : null;
                    },
                  ),

                  const SizedBox(height: 12),

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
                      labelText: 'Vehicle model',
                      hintText: 'e.g. Corolla',
                      prefixIcon: Icon(
                        Icons
                            .directions_car_outlined,
                      ),
                    ),
                    validator: (value) {
                      return value
                                  ?.trim()
                                  .isEmpty ??
                              true
                          ? 'Enter vehicle model'
                          : null;
                    },
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller: year,
                    enabled: !saving,
                    keyboardType:
                        TextInputType.number,
                    textInputAction:
                        TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter
                          .digitsOnly,
                      LengthLimitingTextInputFormatter(
                        4,
                      ),
                    ],
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
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller: registration,
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
                          'e.g. WP CAB-1234',
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

            const SizedBox(height: 12),

            _RaVehicleEditorSection(
              icon: Icons.tune_rounded,
              title: 'Specifications',
              subtitle:
                  'Help providers prepare appropriate tools and equipment.',
              child: Column(
                children: [
                  _RaVehicleEditorChoice(
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

                  const SizedBox(height: 12),

                  _RaVehicleEditorChoice(
                    label: 'Fuel type',
                    icon: Icons
                        .local_gas_station_outlined,
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

                  const SizedBox(height: 12),

                  _RaVehicleEditorChoice(
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
                        transmission = value;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.primary
                    .withValues(alpha: .07),
                borderRadius:
                    BorderRadius.circular(17),
                border: Border.all(
                  color: colors.primary
                      .withValues(alpha: .12),
                ),
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
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'These details are reused when you create a roadside request, so keep them accurate.',
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 10,
                        height: 1.45,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            18,
            9,
            18,
            13,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(
              top: BorderSide(
                color: colors.outlineVariant
                    .withValues(alpha: .45),
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
                        ? Icons.save_outlined
                        : Icons
                            .add_circle_outline_rounded,
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
            BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
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

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  editing
                      ? 'Update your vehicle'
                      : 'Add your vehicle',
                  style: GoogleFonts
                      .plusJakartaSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: -.4,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'Accurate vehicle information helps roadside providers prepare before they arrive.',
                  style: GoogleFonts
                      .plusJakartaSans(
                    color: Colors.white
                        .withValues(alpha: .80),
                    fontSize: 10,
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

class _RaVehicleEditorSection
    extends StatelessWidget {
  const _RaVehicleEditorSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark =
        theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFF0D1D2B)
            : Colors.white,
        borderRadius:
            BorderRadius.circular(21),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .48),
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
                width: 41,
                height: 41,
                decoration: BoxDecoration(
                  color: colors.primary
                      .withValues(alpha: .08),
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: colors.primary,
                  size: 20,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 9.5,
                        height: 1.4,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 17),

          child,
        ],
      ),
    );
  }
}

class _RaVehicleEditorChoice
    extends StatelessWidget {
  const _RaVehicleEditorChoice({
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
            (item) =>
                DropdownMenuItem<String>(
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

class _RaVehiclePhotoSource
    extends StatelessWidget {
  const _RaVehiclePhotoSource({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Material(
      color: colors
          .surfaceContainerHighest
          .withValues(alpha: .36),
      borderRadius:
          BorderRadius.circular(17),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(17),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: colors.primary
                      .withValues(alpha: .08),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: colors.primary,
                  size: 19,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 9,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right_rounded,
                color:
                    colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}