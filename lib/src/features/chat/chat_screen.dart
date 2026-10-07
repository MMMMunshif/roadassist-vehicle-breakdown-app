part of '../../screens.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.requestId,
    this.peerName = 'Service Provider',
    this.peerPhone = '',
  });

  final String? requestId;
  final String peerName;
  final String peerPhone;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

Future<Map<String, dynamic>?> requestProviderQuote(
  BuildContext context,
  Map<String, dynamic> requestData,
) async {
  var distanceKm =
      (requestData['providerDistanceKm'] as num?)?.toDouble() ?? 0.0;

  final driverLatitude = (requestData['latitude'] as num?)?.toDouble();
  final driverLongitude = (requestData['longitude'] as num?)?.toDouble();

  if (requestData['repairRevision'] != true &&
      driverLatitude != null &&
      driverLongitude != null) {
    try {
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        final providerPosition = await Geolocator.getCurrentPosition();

        distanceKm =
            Geolocator.distanceBetween(
              providerPosition.latitude,
              providerPosition.longitude,
              driverLatitude,
              driverLongitude,
            ) /
            1000;
      }
    } catch (_) {
      // Provider can still manually enter the travel charge.
    }
  }

  if (!context.mounted) return null;

  final revision = requestData['repairRevision'] == true;
  final desired = requestData['proposedTotal'] as int?;

  final travel = revision
      ? (requestData['dispatchFee'] as num?)?.toInt() ?? 0
      : 0;

  final extra = revision ? (requestData['extraFee'] as num?)?.toInt() ?? 0 : 0;

  final keepFees = desired == null || desired >= travel + extra;

  final serviceController = TextEditingController(
    text:
        '${desired == null ? (requestData['serviceFee'] as num?)?.toInt() ?? 0 : desired - (keepFees ? travel + extra : 0)}',
  );

  final travelController = TextEditingController(
    text: '${keepFees ? travel : 0}',
  );

  final extraController = TextEditingController(
    text: '${keepFees ? extra : 0}',
  );

  final notesController = TextEditingController();
  final reasonController = TextEditingController();
  final warrantyController = TextEditingController();

  var warrantyDays = 0;
  var inspectionOnly = false;
  var preparingPhoto = false;

  String? evidenceError;

  final evidence = <String>[];

  int amount(TextEditingController controller) {
    return int.tryParse(controller.text.replaceAll(',', '').trim()) ?? 0;
  }

  final quoteRoute = DialogRoute<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final colors = Theme.of(context).colorScheme;

          final total =
              amount(serviceController) +
              amount(travelController) +
              amount(extraController);

          final revisionError = revision
              ? validateRepairRevision(
                  previousTotal:
                      (requestData['estimatedCost'] as num?)?.toInt() ?? 0,
                  total: total,
                  reason: reasonController.text,
                  photos: evidence,
                )
              : null;

          final warrantyInvalid =
              !inspectionOnly &&
              warrantyDays > 0 &&
              warrantyController.text.trim().length < 10;

          final notesInvalid =
              requestData['workflowVersion'] == 2 &&
              notesController.text.trim().isEmpty;

          final invalidTotal = revision ? total < 0 : total <= 0;

          final canSubmit =
              !invalidTotal &&
              !preparingPhoto &&
              !warrantyInvalid &&
              revisionError == null &&
              total <= 10000000 &&
              !notesInvalid;

          Future<void> attachEvidence(ImageSource source) async {
            if (preparingPhoto || evidence.length >= 2) {
              return;
            }

            setDialogState(() {
              preparingPhoto = true;
              evidenceError = null;
            });

            try {
              final photo = source == ImageSource.camera
                  ? await Navigator.of(dialogContext).push<XFile>(
                      MaterialPageRoute(
                        builder: (_) => const CameraCaptureScreen(),
                      ),
                    )
                  : await ImagePicker().pickImage(
                      source: source,
                      imageQuality: 70,
                      maxWidth: 1200,
                    );

              if (photo == null) return;

              final encoded = await PhotoUploadService().prepareVehiclePhoto(
                photo,
              );

              if (dialogContext.mounted) {
                setDialogState(() {
                  evidence.add(encoded);
                });
              }
            } catch (_) {
              if (dialogContext.mounted) {
                setDialogState(() {
                  evidenceError =
                      'Could not prepare the photo. Choose a supported image and try again.';
                });
              }
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() {
                  preparingPhoto = false;
                });
              }
            }
          }

          Widget moneyField(
            String label,
            TextEditingController controller,
            IconData icon,
          ) {
            return TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(7),
              ],
              onChanged: (_) => setDialogState(() {}),
              decoration: InputDecoration(
                labelText: label,
                prefixText: 'Rs. ',
                prefixIcon: Icon(icon),
              ),
            );
          }

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: RaSpace.lg,
              vertical: RaSpace.xl,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight: MediaQuery.sizeOf(context).height * .90,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      RaSpace.lg,
                      RaSpace.lg,
                      RaSpace.sm,
                      RaSpace.md,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.request_quote_outlined,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: RaSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                revision
                                    ? 'Revise approved quote'
                                    : 'Create service offer',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                revision
                                    ? 'Explain the change clearly before requesting driver approval.'
                                    : 'Review the request and send a transparent itemized price.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: preparingPhoto
                              ? null
                              : () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(RaSpace.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _RaChatQuoteRequestSummary(
                            issue:
                                requestData['issue'] as String? ??
                                'Roadside assistance',
                            distanceKm: distanceKm,
                            vehicle: requestData['modelYear'] as String? ?? '',
                            description:
                                requestData['description'] as String? ?? '',
                            partsPreference:
                                requestData['partsPreference'] as String? ??
                                'discuss',
                            photoData: requestVehiclePhoto(requestData),
                          ),
                          const SizedBox(height: RaSpace.xl),

                          if (requestData['workflowVersion'] == 2 && !revision)
                            _RaChatQuoteInspectionCard(
                              value: inspectionOnly,
                              onChanged: (value) {
                                setDialogState(() {
                                  inspectionOnly = value;

                                  if (inspectionOnly) {
                                    warrantyDays = 0;
                                  }
                                });
                              },
                            ),

                          if (requestData['workflowVersion'] == 2 && !revision)
                            const SizedBox(height: RaSpace.xl),

                          if (revision) ...[
                            _RaChatQuoteNotice(
                              icon: Icons.history_rounded,
                              title:
                                  'Previously approved: Rs. ${requestData['estimatedCost'] ?? 0}',
                              message:
                                  'Enter the full replacement total. Explain the new problem, additional work and parts. Do not begin extra work until the driver approves it.',
                            ),
                            const SizedBox(height: RaSpace.xl),
                          ],

                          const _RaChatQuoteSectionTitle(
                            icon: Icons.payments_outlined,
                            title: 'Price breakdown',
                            subtitle:
                                'Keep each charge separate so the driver can understand the total.',
                          ),

                          const SizedBox(height: RaSpace.md),

                          moneyField(
                            inspectionOnly
                                ? 'Visit / inspection charge'
                                : 'Service / labour charge',
                            serviceController,
                            Icons.build_outlined,
                          ),

                          const SizedBox(height: RaSpace.sm),

                          moneyField(
                            'Travel / distance charge',
                            travelController,
                            Icons.route_outlined,
                          ),

                          const SizedBox(height: RaSpace.sm),

                          moneyField(
                            'Extra charge',
                            extraController,
                            Icons.add_card_outlined,
                          ),

                          const SizedBox(height: RaSpace.xl),

                          const _RaChatQuoteSectionTitle(
                            icon: Icons.description_outlined,
                            title: 'Offer details',
                            subtitle:
                                'Describe what is included and anything the driver should know before approving.',
                          ),

                          const SizedBox(height: RaSpace.md),

                          TextField(
                            controller: notesController,
                            onChanged: (_) => setDialogState(() {}),
                            maxLength: 200,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Included work, parts and exclusions',
                              hintText:
                                  'Example: labour included, parts extra after approval',
                              alignLabelWithHint: true,
                            ),
                          ),

                          const SizedBox(height: RaSpace.sm),

                          DropdownButtonFormField<int>(
                            initialValue: warrantyDays,
                            decoration: const InputDecoration(
                              labelText: 'Service warranty',
                              prefixIcon: Icon(Icons.verified_user_outlined),
                            ),
                            items: [0, 7, 14, 30, 90, 180, 365]
                                .map(
                                  (days) => DropdownMenuItem(
                                    value: days,
                                    child: Text(
                                      days == 0
                                          ? 'No service warranty'
                                          : '$days days',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: inspectionOnly
                                ? null
                                : (value) {
                                    setDialogState(
                                      () => warrantyDays = value ?? 0,
                                    );
                                  },
                          ),

                          if (warrantyDays > 0 && !inspectionOnly) ...[
                            const SizedBox(height: RaSpace.sm),
                            TextField(
                              controller: warrantyController,
                              maxLength: 500,
                              maxLines: 3,
                              onChanged: (_) => setDialogState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Warranty coverage',
                                hintText:
                                    'State what repair, parts and labour are covered.',
                                alignLabelWithHint: true,
                                errorText: warrantyInvalid
                                    ? 'Add at least 10 characters describing the warranty.'
                                    : null,
                              ),
                            ),
                            const SizedBox(height: RaSpace.xs),
                            Text(
                              'Warranty begins when the driver confirms completion and only covers the work stated here.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],

                          if (revision) ...[
                            const SizedBox(height: RaSpace.xl),

                            const _RaChatQuoteSectionTitle(
                              icon: Icons.change_circle_outlined,
                              title: 'Reason for revision',
                              subtitle:
                                  'Tell the driver exactly what changed after inspection or repair began.',
                            ),

                            const SizedBox(height: RaSpace.md),

                            TextField(
                              controller: reasonController,
                              maxLength: 300,
                              maxLines: 3,
                              onChanged: (_) => setDialogState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Reason for price / work change',
                                hintText:
                                    'Explain what was discovered and why the change is required.',
                                alignLabelWithHint: true,
                              ),
                            ),

                            const SizedBox(height: RaSpace.md),

                            _RaChatQuoteEvidenceSection(
                              evidence: evidence,
                              preparingPhoto: preparingPhoto,
                              evidenceError: evidenceError,
                              onGallery: () =>
                                  attachEvidence(ImageSource.gallery),
                              onCamera: () =>
                                  attachEvidence(ImageSource.camera),
                              onRemove: (index) {
                                setDialogState(() => evidence.removeAt(index));
                              },
                            ),

                            if (revisionError != null) ...[
                              const SizedBox(height: RaSpace.sm),
                              _RaChatQuoteValidationMessage(
                                message: revisionError,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),

                  const Divider(height: 1),

                  Padding(
                    padding: const EdgeInsets.all(RaSpace.lg),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(RaSpace.md),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer.withValues(
                              alpha: .5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      revision
                                          ? 'New full total'
                                          : inspectionOnly
                                          ? 'Inspection total'
                                          : 'Quoted total',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelLarge,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      revision
                                          ? 'This replaces the previously approved amount.'
                                          : 'Driver sees this before accepting your offer.',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: RaSpace.md),
                              Text(
                                'Rs. $total',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: RaSpace.md),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: preparingPhoto
                                    ? null
                                    : () => Navigator.pop(dialogContext),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: RaSpace.sm),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                onPressed: !canSubmit
                                    ? null
                                    : () => Navigator.pop(dialogContext, {
                                        'serviceFee': amount(serviceController),
                                        'travelFee': amount(travelController),
                                        'extraFee': amount(extraController),
                                        'providerDistanceKm': distanceKm,
                                        'quoteNotes': notesController.text
                                            .trim(),
                                        'quoteType': inspectionOnly
                                            ? 'inspection'
                                            : 'direct',
                                        'warrantyDays': inspectionOnly
                                            ? 0
                                            : warrantyDays,
                                        'warrantyTerms':
                                            inspectionOnly || warrantyDays == 0
                                            ? ''
                                            : warrantyController.text.trim(),
                                        if (revision)
                                          'changeReason': reasonController.text
                                              .trim(),
                                        if (revision)
                                          'evidencePhotoData':
                                              List<String>.from(evidence),
                                      }),
                                icon: const Icon(Icons.send_rounded),
                                label: Text(
                                  requestData['workflowVersion'] == 2
                                      ? revision
                                            ? 'Send Revision'
                                            : 'Send Offer'
                                      : 'Accept with Quote',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  final result = await Navigator.of(
    context,
    rootNavigator: true,
  ).push(quoteRoute);
  await quoteRoute.completed;

  serviceController.dispose();
  travelController.dispose();
  extraController.dispose();
  notesController.dispose();
  reasonController.dispose();
  warrantyController.dispose();

  return result;
}

class _RaChatQuoteSectionTitle extends StatelessWidget {
  const _RaChatQuoteSectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: colors.onPrimaryContainer),
        ),
        const SizedBox(width: RaSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _RaChatQuoteRequestSummary extends StatelessWidget {
  const _RaChatQuoteRequestSummary({
    required this.issue,
    required this.distanceKm,
    required this.vehicle,
    required this.description,
    required this.partsPreference,
    required this.photoData,
  });

  final String issue;
  final double distanceKm;
  final String vehicle;
  final String description;
  final String partsPreference;
  final String photoData;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(RaSpace.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  issue,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (distanceKm > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${distanceKm.toStringAsFixed(1)} km',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),

          if (vehicle.trim().isNotEmpty) ...[
            const SizedBox(height: RaSpace.sm),
            Text(
              'Vehicle: $vehicle',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],

          const SizedBox(height: RaSpace.md),

          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: VehiclePhotoPreview(
              model: vehicle,
              photoData: photoData,
              height: 125,
            ),
          ),

          const SizedBox(height: RaSpace.sm),

          Text(
            'Confirm the vehicle year, engine / variant and part number before choosing parts.',
            style: Theme.of(context).textTheme.bodySmall,
          ),

          if (description.trim().isNotEmpty) ...[
            const SizedBox(height: RaSpace.sm),
            Text(
              'Driver symptoms',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 2),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
          ],

          const SizedBox(height: RaSpace.sm),

          Text(
            'Parts preference: $partsPreference',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _RaChatQuoteInspectionCard extends StatelessWidget {
  const _RaChatQuoteInspectionCard({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.secondaryContainer.withValues(alpha: .35),
      borderRadius: BorderRadius.circular(18),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: RaSpace.md,
          vertical: RaSpace.xs,
        ),
        secondary: Icon(Icons.search_rounded, color: colors.secondary),
        title: const Text('Inspection required'),
        subtitle: const Text(
          'This offer covers the visit and inspection only. Repair work needs a separate driver-approved quote.',
        ),
      ),
    );
  }
}

class _RaChatQuoteNotice extends StatelessWidget {
  const _RaChatQuoteNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(RaSpace.md),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.onTertiaryContainer),
          const SizedBox(width: RaSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RaChatQuoteEvidenceSection extends StatelessWidget {
  const _RaChatQuoteEvidenceSection({
    required this.evidence,
    required this.preparingPhoto,
    required this.evidenceError,
    required this.onGallery,
    required this.onCamera,
    required this.onRemove,
  });

  final List<String> evidence;
  final bool preparingPhoto;
  final String? evidenceError;
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canAdd = !preparingPhoto && evidence.length < 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Photo evidence',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          'Required for a price increase. Show the damaged part, repair or relevant parts receipt.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: RaSpace.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canAdd ? onGallery : null,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Gallery'),
              ),
            ),
            const SizedBox(width: RaSpace.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canAdd ? onCamera : null,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Camera'),
              ),
            ),
          ],
        ),
        if (preparingPhoto) ...[
          const SizedBox(height: RaSpace.sm),
          const LinearProgressIndicator(minHeight: 3),
        ],
        if (evidence.isNotEmpty) ...[
          const SizedBox(height: RaSpace.md),
          Wrap(
            spacing: RaSpace.sm,
            runSpacing: RaSpace.sm,
            children: [
              for (var index = 0; index < evidence.length; index++)
                _RaChatQuoteEvidenceThumbnail(
                  data: evidence[index],
                  onRemove: preparingPhoto ? null : () => onRemove(index),
                ),
            ],
          ),
        ],
        if (evidenceError != null) ...[
          const SizedBox(height: RaSpace.sm),
          Text(
            evidenceError!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.error),
          ),
        ],
      ],
    );
  }
}

class _RaChatQuoteEvidenceThumbnail extends StatelessWidget {
  const _RaChatQuoteEvidenceThumbnail({
    required this.data,
    required this.onRemove,
  });

  final String data;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    Widget image;

    try {
      image = Image.memory(base64Decode(data), fit: BoxFit.cover);
    } on FormatException {
      image = const Center(child: Icon(Icons.broken_image_outlined));
    }

    return Stack(
      children: [
        Container(
          width: 118,
          height: 88,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: image,
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton.filled(
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            onPressed: onRemove,
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: .58),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ],
    );
  }
}

class _RaChatQuoteValidationMessage extends StatelessWidget {
  const _RaChatQuoteValidationMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(RaSpace.md),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: colors.error, size: 20),
          const SizedBox(width: RaSpace.sm),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final controller = TextEditingController();
  final scrollController = ScrollController();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? messageListener;

  final messages = <String>[];
  final senderIds = <String>[];
  final messageImages = <String?>[];
  final messageTimes = <DateTime?>[];

  bool attachingPhoto = false;
  bool sendingMessage = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    controller.addListener(_onComposerChanged);

    if (widget.requestId != null) {
      unawaited(
        RequestService()
            .markChatSeen(widget.requestId!)
            .catchError((Object error) {}),
      );

      messageListener = RequestService()
          .watchMessages(widget.requestId!)
          .listen((snapshot) {
            if (!mounted) return;

            setState(() {
              messages
                ..clear()
                ..addAll(
                  snapshot.docs.map(
                    (doc) => doc.data()['text'] as String? ?? '',
                  ),
                );

              senderIds
                ..clear()
                ..addAll(
                  snapshot.docs.map(
                    (doc) => doc.data()['senderId'] as String? ?? '',
                  ),
                );

              messageImages
                ..clear()
                ..addAll(
                  snapshot.docs.map(
                    (doc) => doc.data()['imageData'] as String?,
                  ),
                );

              messageTimes
                ..clear()
                ..addAll(
                  snapshot.docs.map((doc) {
                    final value = doc.data()['createdAt'];

                    if (value is Timestamp) {
                      return value.toDate();
                    }

                    if (value is DateTime) {
                      return value;
                    }

                    return null;
                  }),
                );
            });

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToLatest();
            });

            if (ModalRoute.of(context)?.isCurrent == true &&
                WidgetsBinding.instance.lifecycleState ==
                    AppLifecycleState.resumed) {
              unawaited(
                RequestService()
                    .markChatSeen(widget.requestId!)
                    .catchError((Object error) {}),
              );
            }
          });
    }
  }

  void _onComposerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        widget.requestId != null &&
        ModalRoute.of(context)?.isCurrent == true) {
      unawaited(
        RequestService()
            .markChatSeen(widget.requestId!)
            .catchError((Object error) {}),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_onComposerChanged);
    messageListener?.cancel();
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void _scrollToLatest({bool animated = true}) {
    if (!scrollController.hasClients) {
      return;
    }

    final target = scrollController.position.maxScrollExtent;

    if (animated) {
      scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      scrollController.jumpTo(target);
    }
  }

  Future<void> _openAttachmentSheet() async {
    if (widget.requestId == null || attachingPhoto) {
      return;
    }

    final action = await showModalBottomSheet<_RaChatAttachmentAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            RaSpace.lg,
            0,
            RaSpace.lg,
            RaSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Share with ${widget.peerName}',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Choose what you want to send in this roadside assistance chat.',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: RaSpace.lg),
              _RaChatAttachmentTile(
                icon: Icons.photo_library_outlined,
                title: 'Photo library',
                subtitle: 'Choose a photo from your device',
                onTap: () => Navigator.pop(
                  sheetContext,
                  _RaChatAttachmentAction.gallery,
                ),
              ),
              const SizedBox(height: RaSpace.sm),
              _RaChatAttachmentTile(
                icon: Icons.camera_alt_outlined,
                title: 'Camera',
                subtitle: 'Take a new photo',
                onTap: () =>
                    Navigator.pop(sheetContext, _RaChatAttachmentAction.camera),
              ),
              const SizedBox(height: RaSpace.sm),
              _RaChatAttachmentTile(
                icon: Icons.my_location_outlined,
                title: 'Current location',
                subtitle: 'Share your current Google Maps location',
                onTap: () => Navigator.pop(
                  sheetContext,
                  _RaChatAttachmentAction.location,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _RaChatAttachmentAction.gallery:
        await _attachPhoto(ImageSource.gallery);
      case _RaChatAttachmentAction.camera:
        await _attachPhoto(ImageSource.camera);
      case _RaChatAttachmentAction.location:
        await shareCurrentLocation();
    }
  }

  Future<void> _attachPhoto(ImageSource source) async {
    if (widget.requestId == null || attachingPhoto) {
      return;
    }

    final navigator = Navigator.of(context);

    final photo = source == ImageSource.camera
        ? await navigator.push<XFile>(
            MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
          )
        : await ImagePicker().pickImage(
            source: ImageSource.gallery,
            imageQuality: 75,
            maxWidth: 1400,
          );

    if (photo == null || !mounted) {
      return;
    }

    setState(() {
      attachingPhoto = true;
    });

    try {
      final imageData = await PhotoUploadService().prepareChatPhoto(photo);

      await RequestService().sendChatPhoto(widget.requestId!, imageData);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to send photo: $error')));
    } finally {
      if (mounted) {
        setState(() {
          attachingPhoto = false;
        });
      }
    }
  }

  Future<void> shareCurrentLocation() async {
    if (widget.requestId == null) {
      return;
    }

    try {
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const PermissionDeniedException('Location permission denied.');
      }

      final position = await Geolocator.getCurrentPosition();

      final mapLink =
          'Current location: https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

      await RequestService().sendMessage(widget.requestId!, mapLink);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to share current location.')),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = controller.text.trim();

    if (text.isEmpty || sendingMessage) {
      return;
    }

    if (widget.requestId == null) {
      controller.clear();

      setState(() {
        messages.add(text);
        senderIds.add('local-me');
        messageImages.add(null);
        messageTimes.add(DateTime.now());
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToLatest();
      });

      return;
    }

    setState(() {
      sendingMessage = true;
    });

    try {
      await RequestService().sendMessage(widget.requestId!, text);

      if (mounted) {
        controller.clear();
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Message could not be sent. Check your connection and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          sendingMessage = false;
        });
      }
    }
  }

  bool _isMine(int index) {
    if (widget.requestId == null) {
      return senderIds[index] == 'local-me';
    }

    return senderIds[index] == FirebaseAuth.instance.currentUser?.uid;
  }

  bool _showDateSeparator(int index) {
    if (index < 0 || index >= messageTimes.length) {
      return false;
    }

    final current = messageTimes[index];

    if (current == null) {
      return false;
    }

    if (index == 0) {
      return true;
    }

    final previous = messageTimes[index - 1];

    if (previous == null) {
      return true;
    }

    return current.year != previous.year ||
        current.month != previous.month ||
        current.day != previous.day;
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final value = DateTime(date.year, date.month, date.day);

    final days = today.difference(value).inDays;

    if (days == 0) {
      return 'Today';
    }

    if (days == 1) {
      return 'Yesterday';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _timeLabel(DateTime? date) {
    if (date == null) return '';

    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;

    final minute = date.minute.toString().padLeft(2, '0');

    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  Widget _buildJobContext() {
    if (widget.requestId == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: RequestService().watchRequest(widget.requestId!),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();

        if (data == null) {
          return const SizedBox.shrink();
        }

        return _RaChatJobContextCard(
          issue: requestIssueLabel(data),
          status: data['status'] as String? ?? '',
          vehicle: [
            data['modelYear'] as String? ?? '',
            data['registration'] as String? ?? '',
          ].where((value) => value.trim().isNotEmpty).join(' • '),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 4,
        title: Row(
          children: [
            ProfileInitials(name: widget.peerName, radius: 20),
            const SizedBox(width: RaSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.peerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'RoadAssist conversation',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (widget.peerPhone.isNotEmpty)
            IconButton.filledTonal(
              onPressed: () => showCallPrompt(
                context,
                name: widget.peerName,
                number: widget.peerPhone,
              ),
              tooltip: 'Call ${widget.peerName}',
              icon: const Icon(Icons.call_outlined),
            ),
          const SizedBox(width: RaSpace.sm),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildJobContext(),

            Expanded(
              child: messages.isEmpty
                  ? _RaChatEmptyConversation(peerName: widget.peerName)
                  : ListView.builder(
                      controller: scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(
                        RaSpace.lg,
                        RaSpace.lg,
                        RaSpace.lg,
                        RaSpace.xl,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final mine = _isMine(index);

                        final date = index < messageTimes.length
                            ? messageTimes[index]
                            : null;

                        final imageData = index < messageImages.length
                            ? messageImages[index]
                            : null;

                        return Column(
                          children: [
                            if (_showDateSeparator(index) && date != null)
                              _RaChatDateSeparator(label: _dateLabel(date)),

                            _RaChatMessageBubble(
                              text: messages[index],
                              imageData: imageData,
                              mine: mine,
                              peerName: widget.peerName,
                              timeLabel: _timeLabel(date),
                            ),
                          ],
                        );
                      },
                    ),
            ),

            _RaChatComposer(
              controller: controller,
              attachingPhoto: attachingPhoto,
              sendingMessage: sendingMessage,
              enabled: true,
              canAttach: widget.requestId != null,
              onAttachment: _openAttachmentSheet,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

enum _RaChatAttachmentAction { gallery, camera, location }

class _RaChatAttachmentTile extends StatelessWidget {
  const _RaChatAttachmentTile({
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
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .65)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(RaSpace.md),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colors.onPrimaryContainer),
              ),
              const SizedBox(width: RaSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaChatJobContextCard extends StatelessWidget {
  const _RaChatJobContextCard({
    required this.issue,
    required this.status,
    required this.vehicle,
  });

  final String issue;
  final String status;
  final String vehicle;

  String get statusLabel => switch (status) {
    'searching' => 'Searching',
    'accepted' => 'Accepted',
    'en_route' => 'En route',
    'arrived' => 'Arrived',
    'completed' => 'Completed',
    'cancelled' => 'Cancelled',
    _ => status.replaceAll('_', ' '),
  };

  RaTone get statusTone => switch (status) {
    'completed' => RaTone.success,
    'cancelled' => RaTone.danger,
    'accepted' || 'en_route' || 'arrived' => RaTone.success,
    _ => RaTone.info,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        RaSpace.lg,
        RaSpace.sm,
        RaSpace.lg,
        RaSpace.md,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: .55),
          ),
        ),
      ),
      child: Material(
        color: colors.primaryContainer.withValues(alpha: .32),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(RaSpace.md),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.car_repair_outlined,
                  color: colors.onPrimaryContainer,
                ),
              ),

              const SizedBox(width: RaSpace.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (vehicle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        vehicle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: RaSpace.sm),

              StatusPill(label: statusLabel, tone: statusTone),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaChatDateSeparator extends StatelessWidget {
  const _RaChatDateSeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RaSpace.md),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: colors.outlineVariant.withValues(alpha: .65)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RaSpace.md),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: colors.outlineVariant.withValues(alpha: .65)),
          ),
        ],
      ),
    );
  }
}

class _RaChatMessageBubble extends StatelessWidget {
  const _RaChatMessageBubble({
    required this.text,
    required this.imageData,
    required this.mine,
    required this.peerName,
    required this.timeLabel,
  });

  final String text;
  final String? imageData;
  final bool mine;
  final String peerName;
  final String timeLabel;

  bool get isLocation =>
      text.startsWith('Current location: http://') ||
      text.startsWith('Current location: https://');

  String get locationUrl =>
      isLocation ? text.substring('Current location: '.length).trim() : '';

  Future<void> _openLocation(BuildContext context) async {
    if (!isLocation) return;

    final uri = Uri.tryParse(locationUrl);

    if (uri == null) return;

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the shared location.')),
      );
    }
  }

  void _showPhoto(BuildContext context, String data) {
    try {
      final bytes = base64Decode(data);

      showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .88),
        builder: (dialogContext) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: .8,
                    maxScale: 4,
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  top: RaSpace.sm,
                  right: RaSpace.sm,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: .14),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This photo could not be displayed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .76,
        ),
        margin: const EdgeInsets.only(bottom: RaSpace.sm),
        decoration: BoxDecoration(
          color: mine ? colors.primary : colors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(mine ? 20 : 5),
            bottomRight: Radius.circular(mine ? 5 : 20),
          ),
          border: mine
              ? null
              : Border.all(color: colors.outlineVariant.withValues(alpha: .65)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? .12 : .04,
              ),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(mine ? 20 : 5),
            bottomRight: Radius.circular(mine ? 5 : 20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageData != null && imageData!.isNotEmpty)
                _RaChatPhotoMessage(
                  imageData: imageData!,
                  onTap: () => _showPhoto(context, imageData!),
                )
              else if (isLocation)
                _RaChatLocationMessage(
                  mine: mine,
                  onTap: () => _openLocation(context),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    RaSpace.md,
                    11,
                    RaSpace.md,
                    8,
                  ),
                  child: Text(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: mine ? colors.onPrimary : colors.onSurface,
                      height: 1.4,
                    ),
                  ),
                ),

              if (timeLabel.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    RaSpace.md,
                    imageData != null || isLocation ? 8 : 0,
                    RaSpace.md,
                    8,
                  ),
                  child: Text(
                    timeLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: mine
                          ? colors.onPrimary.withValues(alpha: .72)
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaChatPhotoMessage extends StatelessWidget {
  const _RaChatPhotoMessage({required this.imageData, required this.onTap});

  final String imageData;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    try {
      final bytes = base64Decode(imageData);

      return GestureDetector(
        onTap: onTap,
        child: Image.memory(
          bytes,
          width: 250,
          height: 190,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stack) => const SizedBox(
            width: 250,
            height: 150,
            child: Center(child: Icon(Icons.broken_image_outlined)),
          ),
        ),
      );
    } on FormatException {
      return const SizedBox(
        width: 250,
        height: 150,
        child: Center(child: Icon(Icons.broken_image_outlined)),
      );
    }
  }
}

class _RaChatLocationMessage extends StatelessWidget {
  const _RaChatLocationMessage({required this.mine, required this.onTap});

  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final foreground = mine ? colors.onPrimary : colors.onSurface;

    final secondary = mine
        ? colors.onPrimary.withValues(alpha: .78)
        : colors.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(RaSpace.md),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: mine
                    ? Colors.white.withValues(alpha: .14)
                    : colors.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.location_on_rounded,
                color: mine ? colors.onPrimary : colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: RaSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shared location',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to open in Maps',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: secondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, size: 18, color: secondary),
          ],
        ),
      ),
    );
  }
}

class _RaChatEmptyConversation extends StatelessWidget {
  const _RaChatEmptyConversation({required this.peerName});

  final String peerName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(RaSpace.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(
                Icons.forum_outlined,
                color: colors.onPrimaryContainer,
                size: 36,
              ),
            ),
            const SizedBox(height: RaSpace.lg),
            Text(
              'Start the conversation',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: RaSpace.sm),
            Text(
              'Message $peerName about the current roadside assistance job. You can also share photos or your current location.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _RaChatComposer extends StatelessWidget {
  const _RaChatComposer({
    required this.controller,
    required this.attachingPhoto,
    required this.sendingMessage,
    required this.enabled,
    required this.canAttach,
    required this.onAttachment,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool attachingPhoto;
  final bool sendingMessage;
  final bool enabled;
  final bool canAttach;

  final VoidCallback onAttachment;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final hasText = controller.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        RaSpace.sm,
        RaSpace.sm,
        RaSpace.sm,
        RaSpace.md,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: .65)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton.filledTonal(
              tooltip: 'Add attachment',
              onPressed: canAttach && !attachingPhoto ? onAttachment : null,
              icon: attachingPhoto
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
            ),

            const SizedBox(width: RaSpace.sm),

            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: enabled
                      ? 'Type a message…'
                      : 'Messaging unavailable',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  filled: true,
                  fillColor: colors.surfaceContainerHighest.withValues(
                    alpha: .45,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(
                      color: colors.primary.withValues(alpha: .45),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: RaSpace.sm),

            IconButton.filled(
              tooltip: 'Send message',
              onPressed: enabled && hasText && !sendingMessage
                  ? () => unawaited(onSend())
                  : null,
              icon: sendingMessage
                  ? SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
