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
  State<ChatScreen> createState() =>
      _ChatScreenState();
}

// =============================================================================
// PROVIDER QUOTE / REVISION DIALOG
// =============================================================================

Future<Map<String, dynamic>?> requestProviderQuote(
  BuildContext context,
  Map<String, dynamic> requestData,
) async {
  final quoteNavigator = Navigator.of(context, rootNavigator: true);
  final quoteThemes = InheritedTheme.capture(from: context, to: quoteNavigator.context);
  var distanceKm =
      (requestData['providerDistanceKm'] as num?)
              ?.toDouble() ??
          0.0;

  final driverLatitude =
      (requestData['latitude'] as num?)
          ?.toDouble();

  final driverLongitude =
      (requestData['longitude'] as num?)
          ?.toDouble();

  final revision =
      requestData['repairRevision'] == true;

  if (!revision &&
      driverLatitude != null &&
      driverLongitude != null) {
    try {
      var permission =
          await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator
                .requestPermission();
      }

      if (permission !=
              LocationPermission.denied &&
          permission !=
              LocationPermission
                  .deniedForever) {
        final providerPosition =
            await Geolocator
                .getCurrentPosition();

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
      // Provider can still enter the travel price manually.
    }
  }

  if (!context.mounted) {
    return null;
  }

  final desired =
      (requestData['proposedTotal'] as num?)
          ?.toInt();

  final previousTravel = revision
      ? (requestData['dispatchFee'] as num?)
              ?.toInt() ??
          0
      : 0;

  final previousExtra = revision
      ? (requestData['extraFee'] as num?)
              ?.toInt() ??
          0
      : 0;

  final keepFees = desired == null ||
      desired >=
          previousTravel + previousExtra;

  final serviceController =
      TextEditingController(
    text:
        '${desired == null ? (requestData['serviceFee'] as num?)?.toInt() ?? 0 : desired - (keepFees ? previousTravel + previousExtra : 0)}',
  );

  final travelController =
      TextEditingController(
    text:
        '${keepFees ? previousTravel : 0}',
  );

  final extraController =
      TextEditingController(
    text: '${keepFees ? previousExtra : 0}',
  );

  final notesController =
      TextEditingController();

  final reasonController =
      TextEditingController();

  final warrantyController =
      TextEditingController();

  var warrantyDays = 0;
  var inspectionOnly = false;
  var preparingPhoto = false;

  String? evidenceError;

  final evidence = <String>[];

  int amount(
    TextEditingController controller,
  ) {
    return int.tryParse(
          controller.text
              .replaceAll(',', '')
              .trim(),
        ) ??
        0;
  }

  Future<void> addEvidence(
    BuildContext dialogContext,
    StateSetter setDialogState,
    ImageSource source,
  ) async {
    if (preparingPhoto ||
        evidence.length >= 2) {
      return;
    }

    setDialogState(() {
      preparingPhoto = true;
      evidenceError = null;
    });

    try {
      final photo =
          source == ImageSource.camera
              ? await Navigator.of(
                  dialogContext,
                ).push<XFile>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const CameraCaptureScreen(),
                  ),
                )
              : await ImagePicker()
                  .pickImage(
                  source: source,
                  imageQuality: 70,
                  maxWidth: 1200,
                );

      if (photo == null) {
        return;
      }

      final encoded =
          await PhotoUploadService()
              .prepareVehiclePhoto(
        photo,
      );

      if (!dialogContext.mounted) {
        return;
      }

      setDialogState(() {
        evidence.add(encoded);
      });
    } catch (_) {
      if (!dialogContext.mounted) {
        return;
      }

      setDialogState(() {
        evidenceError =
            'Could not prepare the photo. Choose another image and try again.';
      });
    } finally {
      if (dialogContext.mounted) {
        setDialogState(() {
          preparingPhoto = false;
        });
      }
    }
  }

  if (!context.mounted) return null;
  final quoteRoute = DialogRoute<Map<String, dynamic>>(
    context: context,
    themes: quoteThemes,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (
          context,
          setDialogState,
        ) {
          final theme =
              Theme.of(context);

          final colors =
              theme.colorScheme;

          final total =
              amount(serviceController) +
                  amount(travelController) +
                  amount(extraController);

          final revisionError = revision
              ? validateRepairRevision(
                  previousTotal:
                      (requestData[
                                  'estimatedCost']
                              as num?)
                          ?.toInt() ??
                      0,
                  total: total,
                  reason:
                      reasonController.text,
                  photos: evidence,
                )
              : null;

          final warrantyInvalid =
              !inspectionOnly &&
                  warrantyDays > 0 &&
                  warrantyController.text
                          .trim()
                          .length <
                      10;

          final notesInvalid =
              requestData[
                      'workflowVersion'] ==
                  2 &&
              notesController.text
                  .trim()
                  .isEmpty;

          final invalidTotal = revision
              ? total < 0
              : total <= 0;

          final canSubmit =
              !invalidTotal &&
                  !preparingPhoto &&
                  !warrantyInvalid &&
                  revisionError == null &&
                  !notesInvalid &&
                  total <= 10000000;

          Widget moneyField({
            required String label,
            required IconData icon,
            required TextEditingController
                controller,
          }) {
            return TextField(
              controller: controller,
              keyboardType:
                  TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter
                    .digitsOnly,
                LengthLimitingTextInputFormatter(
                  7,
                ),
              ],
              onChanged: (_) {
                setDialogState(() {});
              },
              decoration: InputDecoration(
                labelText: label,
                prefixText: 'Rs. ',
                prefixIcon: Icon(icon),
              ),
            );
          }

          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 22,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight:
                    MediaQuery.sizeOf(context)
                            .height *
                        .92,
              ),
              child: Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets
                            .fromLTRB(
                      18,
                      18,
                      10,
                      14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
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
                              15,
                            ),
                          ),
                          child: Icon(
                            revision
                                ? Icons
                                    .change_circle_outlined
                                : Icons
                                    .request_quote_outlined,
                            color: colors
                                .primary,
                          ),
                        ),

                        const SizedBox(
                          width: 12,
                        ),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                revision
                                    ? 'Revise approved quote'
                                    : 'Create service offer',
                                style: GoogleFonts
                                    .plusJakartaSans(
                                  fontSize:
                                      17,
                                  fontWeight:
                                      FontWeight
                                          .w800,
                                  color: colors
                                      .onSurface,
                                ),
                              ),

                              const SizedBox(
                                height: 3,
                              ),

                              Text(
                                revision
                                    ? 'Explain every change before asking for driver approval.'
                                    : 'Send a clear itemized offer before the driver selects you.',
                                style: GoogleFonts
                                    .plusJakartaSans(
                                  fontSize:
                                      9.5,
                                  height: 1.4,
                                  color: colors
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),

                        IconButton(
                          tooltip: 'Close',
                          onPressed:
                              preparingPhoto
                                  ? null
                                  : () {
                                      Navigator.pop(
                                        dialogContext,
                                      );
                                    },
                          icon: const Icon(
                            Icons
                                .close_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Divider(
                    height: 1,
                    color: colors
                        .outlineVariant
                        .withValues(
                      alpha: .45,
                    ),
                  ),

                  Expanded(
                    child:
                        SingleChildScrollView(
                      padding:
                          const EdgeInsets
                              .all(
                        18,
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .stretch,
                        children: [
                          _RaChatQuoteSummary(
                            issue:
                                requestIssueLabel(
                              requestData,
                            ),
                            distanceKm:
                                distanceKm,
                            vehicle:
                                requestData[
                                            'modelYear']
                                        as String? ??
                                    '',
                            description:
                                requestData[
                                            'description']
                                        as String? ??
                                    '',
                            partsPreference:
                                requestData[
                                            'partsPreference']
                                        as String? ??
                                    'discuss',
                            photoData:
                                requestVehiclePhoto(
                              requestData,
                            ),
                          ),

                          const SizedBox(
                            height: 20,
                          ),

                          if (requestData[
                                      'workflowVersion'] ==
                                  2 &&
                              !revision) ...[
                            Container(
                              decoration:
                                  BoxDecoration(
                                color: colors
                                    .secondaryContainer
                                    .withValues(
                                  alpha: .30,
                                ),
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  17,
                                ),
                              ),
                              child:
                                  SwitchListTile(
                                contentPadding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal:
                                      14,
                                  vertical: 3,
                                ),
                                value:
                                    inspectionOnly,
                                secondary:
                                    const Icon(
                                  Icons
                                      .search_rounded,
                                ),
                                title: const Text(
                                  'Inspection required',
                                ),
                                subtitle:
                                    const Text(
                                  'Repair work will require a separate approved revision.',
                                ),
                                onChanged:
                                    (value) {
                                  setDialogState(
                                    () {
                                      inspectionOnly =
                                          value;

                                      if (value) {
                                        warrantyDays =
                                            0;
                                      }
                                    },
                                  );
                                },
                              ),
                            ),

                            const SizedBox(
                              height: 20,
                            ),
                          ],

                          if (revision) ...[
                            _RaChatQuoteNotice(
                              icon: Icons
                                  .history_rounded,
                              title:
                                  'Previously approved: Rs. ${requestData['estimatedCost'] ?? 0}',
                              message:
                                  'The new total replaces the old amount. Extra work should not begin until the driver approves it.',
                            ),
                            const SizedBox(
                              height: 20,
                            ),
                          ],

                          const _RaChatSectionTitle(
                            icon: Icons
                                .payments_outlined,
                            title:
                                'Price breakdown',
                            subtitle:
                                'Keep every charge separate and easy to understand.',
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          moneyField(
                            label: inspectionOnly
                                ? 'Visit / inspection charge'
                                : 'Service / labour charge',
                            icon:
                                Icons.build_outlined,
                            controller:
                                serviceController,
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          moneyField(
                            label:
                                'Travel / distance charge',
                            icon:
                                Icons.route_outlined,
                            controller:
                                travelController,
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          moneyField(
                            label:
                                'Other stated charges',
                            icon: Icons
                                .add_card_outlined,
                            controller:
                                extraController,
                          ),

                          const SizedBox(
                            height: 22,
                          ),

                          const _RaChatSectionTitle(
                            icon: Icons
                                .description_outlined,
                            title:
                                'Offer details',
                            subtitle:
                                'State exactly what is included and excluded.',
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          TextField(
                            controller:
                                notesController,
                            maxLength: 200,
                            minLines: 2,
                            maxLines: 4,
                            onChanged: (_) {
                              setDialogState(
                                () {},
                              );
                            },
                            decoration:
                                InputDecoration(
                              labelText:
                                  'Included work, parts and exclusions',
                              alignLabelWithHint:
                                  true,
                              errorText:
                                  notesInvalid
                                      ? 'Add the work included in this offer.'
                                      : null,
                            ),
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          DropdownButtonFormField<
                              int>(
                            initialValue:
                                warrantyDays,
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'Service warranty',
                              prefixIcon: Icon(
                                Icons
                                    .verified_user_outlined,
                              ),
                            ),
                            items: const [
                              0,
                              7,
                              14,
                              30,
                              90,
                              180,
                              365,
                            ]
                                .map(
                                  (days) =>
                                      DropdownMenuItem<
                                          int>(
                                    value:
                                        days,
                                    child: Text(
                                      days ==
                                              0
                                          ? 'No service warranty'
                                          : '$days days',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged:
                                inspectionOnly
                                    ? null
                                    : (value) {
                                        setDialogState(
                                          () {
                                            warrantyDays =
                                                value ??
                                                    0;
                                          },
                                        );
                                      },
                          ),

                          if (warrantyDays > 0 &&
                              !inspectionOnly) ...[
                            const SizedBox(
                              height: 10,
                            ),

                            TextField(
                              controller:
                                  warrantyController,
                              maxLength: 500,
                              minLines: 2,
                              maxLines: 4,
                              onChanged: (_) {
                                setDialogState(
                                  () {},
                                );
                              },
                              decoration:
                                  InputDecoration(
                                labelText:
                                    'Warranty coverage',
                                alignLabelWithHint:
                                    true,
                                errorText:
                                    warrantyInvalid
                                        ? 'Describe warranty coverage in at least 10 characters.'
                                        : null,
                              ),
                            ),
                          ],

                          if (revision) ...[
                            const SizedBox(
                              height: 22,
                            ),

                            const _RaChatSectionTitle(
                              icon: Icons
                                  .change_circle_outlined,
                              title:
                                  'Reason for revision',
                              subtitle:
                                  'Explain what changed after inspection or repair began.',
                            ),

                            const SizedBox(
                              height: 12,
                            ),

                            TextField(
                              controller:
                                  reasonController,
                              maxLength: 300,
                              minLines: 2,
                              maxLines: 4,
                              onChanged: (_) {
                                setDialogState(
                                  () {},
                                );
                              },
                              decoration:
                                  const InputDecoration(
                                labelText:
                                    'Reason for price / work change',
                                alignLabelWithHint:
                                    true,
                              ),
                            ),

                            const SizedBox(
                              height: 12,
                            ),

                            _RaChatQuoteEvidence(
                              evidence:
                                  evidence,
                              busy:
                                  preparingPhoto,
                              error:
                                  evidenceError,
                              onGallery: () {
                                addEvidence(
                                  dialogContext,
                                  setDialogState,
                                  ImageSource
                                      .gallery,
                                );
                              },
                              onCamera: () {
                                addEvidence(
                                  dialogContext,
                                  setDialogState,
                                  ImageSource
                                      .camera,
                                );
                              },
                              onRemove:
                                  (index) {
                                setDialogState(
                                  () {
                                    evidence
                                        .removeAt(
                                      index,
                                    );
                                  },
                                );
                              },
                            ),

                            if (revisionError !=
                                null) ...[
                              const SizedBox(
                                height: 10,
                              ),

                              _RaChatQuoteNotice(
                                icon: Icons
                                    .error_outline_rounded,
                                title:
                                    'Revision incomplete',
                                message:
                                    revisionError,
                                error: true,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),

                  Divider(
                    height: 1,
                    color: colors
                        .outlineVariant
                        .withValues(
                      alpha: .45,
                    ),
                  ),

                  Padding(
                    padding:
                        const EdgeInsets
                            .all(
                      16,
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding:
                              const EdgeInsets
                                  .all(
                            13,
                          ),
                          decoration:
                              BoxDecoration(
                            color: colors
                                .primary
                                .withValues(
                              alpha: .07,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              16,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                      revision
                                          ? 'New full total'
                                          : inspectionOnly
                                              ? 'Inspection total'
                                              : 'Quoted total',
                                      style: GoogleFonts
                                          .plusJakartaSans(
                                        fontSize:
                                            9,
                                        color: colors
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 3,
                                    ),
                                    Text(
                                      revision
                                          ? 'Replaces the previous approved amount'
                                          : 'Driver reviews this before selection',
                                      style: GoogleFonts
                                          .plusJakartaSans(
                                        fontSize:
                                            8.5,
                                        color: colors
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(
                                width: 12,
                              ),

                              Text(
                                'Rs. $total',
                                style: GoogleFonts
                                    .plusJakartaSans(
                                  fontSize:
                                      17,
                                  fontWeight:
                                      FontWeight
                                          .w800,
                                  color: colors
                                      .primary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          height: 11,
                        ),

                        Row(
                          children: [
                            Expanded(
                              child:
                                  OutlinedButton(
                                onPressed:
                                    preparingPhoto
                                        ? null
                                        : () {
                                            Navigator.pop(
                                              dialogContext,
                                            );
                                          },
                                child:
                                    const Text(
                                  'Cancel',
                                ),
                              ),
                            ),

                            const SizedBox(
                              width: 9,
                            ),

                            Expanded(
                              flex: 2,
                              child:
                                  FilledButton.icon(
                                onPressed:
                                    canSubmit
                                        ? () {
                                            Navigator.pop(
                                              dialogContext,
                                              {
                                                'serviceFee':
                                                    amount(serviceController),
                                                'travelFee':
                                                    amount(travelController),
                                                'extraFee':
                                                    amount(extraController),
                                                'providerDistanceKm':
                                                    distanceKm,
                                                'quoteNotes':
                                                    notesController.text.trim(),
                                                'quoteType':
                                                    inspectionOnly
                                                        ? 'inspection'
                                                        : 'direct',
                                                'warrantyDays':
                                                    inspectionOnly
                                                        ? 0
                                                        : warrantyDays,
                                                'warrantyTerms':
                                                    inspectionOnly ||
                                                            warrantyDays == 0
                                                        ? ''
                                                        : warrantyController.text.trim(),
                                                if (revision)
                                                  'changeReason':
                                                      reasonController.text.trim(),
                                                if (revision)
                                                  'evidencePhotoData':
                                                      List<String>.from(
                                                    evidence,
                                                  ),
                                              },
                                            );
                                          }
                                        : null,
                                icon:
                                    const Icon(
                                  Icons
                                      .send_rounded,
                                ),
                                label: Text(
                                  revision
                                      ? 'Send Revision'
                                      : 'Send Offer',
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

  final result = await Navigator.of(context, rootNavigator: true).push(quoteRoute);
  await quoteRoute.completed;

  serviceController.dispose();
  travelController.dispose();
  extraController.dispose();
  notesController.dispose();
  reasonController.dispose();
  warrantyController.dispose();

  return result;
}

class _RaChatSectionTitle
    extends StatelessWidget {
  const _RaChatSectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
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

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts
                    .plusJakartaSans(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts
                    .plusJakartaSans(
                  fontSize: 9,
                  height: 1.4,
                  color: colors
                      .onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RaChatQuoteSummary
    extends StatelessWidget {
  const _RaChatQuoteSummary({
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
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors
            .surfaceContainerHighest
            .withValues(alpha: .34),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .45),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  issue,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),

              if (distanceKm > 0)
                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration:
                      BoxDecoration(
                    color: colors.primary
                        .withValues(
                      alpha: .08,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      999,
                    ),
                  ),
                  child: Text(
                    '${distanceKm.toStringAsFixed(1)} km',
                    style: GoogleFonts
                        .plusJakartaSans(
                      fontSize: 8,
                      fontWeight:
                          FontWeight.w700,
                      color:
                          colors.primary,
                    ),
                  ),
                ),
            ],
          ),

          if (vehicle
              .trim()
              .isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              vehicle,
              style:
                  GoogleFonts.plusJakartaSans(
                fontSize: 9.5,
                color:
                    colors.onSurfaceVariant,
              ),
            ),
          ],

          const SizedBox(height: 11),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(14),
            child: VehiclePhotoPreview(
              model: vehicle,
              photoData: photoData,
              height: 120,
            ),
          ),

          if (description
              .trim()
              .isNotEmpty) ...[
            const SizedBox(height: 11),
            Text(
              'DRIVER DESCRIPTION',
              style:
                  GoogleFonts.plusJakartaSans(
                fontSize: 8,
                letterSpacing: .7,
                fontWeight:
                    FontWeight.w700,
                color:
                    colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style:
                  GoogleFonts.plusJakartaSans(
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ],

          const SizedBox(height: 8),

          Text(
            'Parts preference: ${partsPreference.replaceAll('_', ' ')}',
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 9,
              color:
                  colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaChatQuoteNotice
    extends StatelessWidget {
  const _RaChatQuoteNotice({
    required this.icon,
    required this.title,
    required this.message,
    this.error = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    final tone =
        error ? colors.error : raGold;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color:
            tone.withValues(alpha: .08),
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: tone,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 9,
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
    );
  }
}

class _RaChatQuoteEvidence
    extends StatelessWidget {
  const _RaChatQuoteEvidence({
    required this.evidence,
    required this.busy,
    required this.error,
    required this.onGallery,
    required this.onCamera,
    required this.onRemove,
  });

  final List<String> evidence;
  final bool busy;
  final String? error;

  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    final canAdd =
        !busy && evidence.length < 2;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Photo evidence',
                style: GoogleFonts
                    .plusJakartaSans(
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${evidence.length}/2',
              style:
                  GoogleFonts.plusJakartaSans(
                fontSize: 8.5,
                color: colors.primary,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    canAdd ? onGallery : null,
                icon: const Icon(
                  Icons
                      .photo_library_outlined,
                ),
                label:
                    const Text('Gallery'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    canAdd ? onCamera : null,
                icon: const Icon(
                  Icons
                      .camera_alt_outlined,
                ),
                label:
                    const Text('Camera'),
              ),
            ),
          ],
        ),

        if (busy) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(
            minHeight: 3,
          ),
        ],

        if (evidence.isNotEmpty) ...[
          const SizedBox(height: 11),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0;
                  index < evidence.length;
                  index++)
                _RaChatEvidencePhoto(
                  data: evidence[index],
                  onRemove: () {
                    onRemove(index);
                  },
                ),
            ],
          ),
        ],

        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error!,
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 9,
              color: colors.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _RaChatEvidencePhoto
    extends StatelessWidget {
  const _RaChatEvidencePhoto({
    required this.data,
    required this.onRemove,
  });

  final String data;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    Widget image;

    try {
      image = Image.memory(
        base64Decode(data),
        fit: BoxFit.cover,
      );
    } on FormatException {
      image = const Center(
        child: Icon(
          Icons.broken_image_outlined,
        ),
      );
    }

    return SizedBox(
      width: 112,
      height: 88,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(14),
              child: image,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton.filled(
              visualDensity:
                  VisualDensity.compact,
              iconSize: 15,
              style:
                  IconButton.styleFrom(
                backgroundColor:
                    Colors.black
                        .withValues(
                  alpha: .58,
                ),
                foregroundColor:
                    Colors.white,
              ),
              onPressed: onRemove,
              icon: const Icon(
                Icons.close_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CHAT
// =============================================================================

class _ChatScreenState
    extends State<ChatScreen>
    with WidgetsBindingObserver {
  final controller =
      TextEditingController();

  final scrollController =
      ScrollController();

  StreamSubscription<
          QuerySnapshot<
              Map<String, dynamic>>>?
      messageListener;

  final messages = <String>[];
  final senderIds = <String>[];
  final messageImages = <String?>[];
  final messageTimes = <DateTime?>[];

  bool attachingPhoto = false;
  bool sendingMessage = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addObserver(this);

    controller.addListener(
      _composerChanged,
    );

    if (widget.requestId != null) {
      _markSeen();

      messageListener = RequestService()
          .watchMessages(
            widget.requestId!,
          )
          .listen(
        (snapshot) {
          if (!mounted) return;

          setState(() {
            messages
              ..clear()
              ..addAll(
                snapshot.docs.map(
                  (doc) =>
                      doc.data()['text']
                          as String? ??
                      '',
                ),
              );

            senderIds
              ..clear()
              ..addAll(
                snapshot.docs.map(
                  (doc) =>
                      doc.data()['senderId']
                          as String? ??
                      '',
                ),
              );

            messageImages
              ..clear()
              ..addAll(
                snapshot.docs.map(
                  (doc) =>
                      doc.data()['imageData']
                          as String?,
                ),
              );

            messageTimes
              ..clear()
              ..addAll(
                snapshot.docs.map(
                  (doc) {
                    final value =
                        doc.data()[
                            'createdAt'];

                    if (value
                        is Timestamp) {
                      return value
                          .toDate();
                    }

                    if (value
                        is DateTime) {
                      return value;
                    }

                    return null;
                  },
                ),
              );
          });

          WidgetsBinding.instance
              .addPostFrameCallback(
            (_) {
              _scrollLatest();
            },
          );

          if (ModalRoute.of(context)
                      ?.isCurrent ==
                  true &&
              WidgetsBinding.instance
                      .lifecycleState ==
                  AppLifecycleState
                      .resumed) {
            _markSeen();
          }
        },
      );
    }
  }

  void _markSeen() {
    final id = widget.requestId;

    if (id == null) return;

    unawaited(
      RequestService()
          .markChatSeen(id)
          .catchError(
        (Object _) {},
      ),
    );
  }

  void _composerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state ==
            AppLifecycleState.resumed &&
        mounted &&
        ModalRoute.of(context)
                ?.isCurrent ==
            true) {
      _markSeen();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance
        .removeObserver(this);

    controller.removeListener(
      _composerChanged,
    );

    messageListener?.cancel();

    controller.dispose();
    scrollController.dispose();

    super.dispose();
  }

  void _scrollLatest() {
    if (!scrollController.hasClients) {
      return;
    }

    scrollController.animateTo(
      scrollController
          .position.maxScrollExtent,
      duration: const Duration(
        milliseconds: 260,
      ),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void>
      _openAttachmentSheet() async {
    if (widget.requestId == null ||
        attachingPhoto) {
      return;
    }

    final action = await showModalBottomSheet<
        _RaChatAttachmentAction>(
      context: context,
      useSafeArea: true,
      backgroundColor:
          Colors.transparent,
      builder: (sheetContext) {
        final theme =
            Theme.of(sheetContext);

        final colors =
            theme.colorScheme;

        final dark =
            theme.brightness ==
                Brightness.dark;

        return Container(
          padding:
              const EdgeInsets.fromLTRB(
            18,
            12,
            18,
            24,
          ),
          decoration: BoxDecoration(
            color: dark
                ? const Color(
                    0xFF0D1D2B,
                  )
                : colors.surface,
            borderRadius:
                const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration:
                      BoxDecoration(
                    color: colors
                        .onSurfaceVariant
                        .withValues(
                      alpha: .24,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      999,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 21),

              Text(
                'Share with ${widget.peerName}',
                style:
                    GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'Choose what you want to send in this roadside conversation.',
                style:
                    GoogleFonts.plusJakartaSans(
                  fontSize: 9.5,
                  color: colors
                      .onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 17),

              _RaChatAttachmentTile(
                icon: Icons
                    .photo_library_outlined,
                title: 'Photo library',
                subtitle:
                    'Choose an existing photo',
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                    _RaChatAttachmentAction
                        .gallery,
                  );
                },
              ),

              const SizedBox(height: 8),

              _RaChatAttachmentTile(
                icon: Icons
                    .camera_alt_outlined,
                title: 'Camera',
                subtitle:
                    'Capture a new photo',
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                    _RaChatAttachmentAction
                        .camera,
                  );
                },
              ),

              const SizedBox(height: 8),

              _RaChatAttachmentTile(
                icon:
                    Icons.my_location_outlined,
                title: 'Current location',
                subtitle:
                    'Share your current map position',
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                    _RaChatAttachmentAction
                        .location,
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _RaChatAttachmentAction.gallery:
        await _attachPhoto(
          ImageSource.gallery,
        );
      case _RaChatAttachmentAction.camera:
        await _attachPhoto(
          ImageSource.camera,
        );
      case _RaChatAttachmentAction.location:
        await shareCurrentLocation();
    }
  }

  Future<void> _attachPhoto(
    ImageSource source,
  ) async {
    final requestId =
        widget.requestId;

    if (requestId == null ||
        attachingPhoto) {
      return;
    }

    final navigator =
        Navigator.of(context);

    final photo =
        source == ImageSource.camera
            ? await navigator.push<XFile>(
                MaterialPageRoute(
                  builder: (_) =>
                      const CameraCaptureScreen(),
                ),
              )
            : await ImagePicker()
                .pickImage(
                source:
                    ImageSource.gallery,
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
      final imageData =
          await PhotoUploadService()
              .prepareChatPhoto(
        photo,
      );

      await RequestService()
          .sendChatPhoto(
        requestId,
        imageData,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Unable to send photo: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          attachingPhoto = false;
        });
      }
    }
  }

  Future<void>
      shareCurrentLocation() async {
    final requestId =
        widget.requestId;

    if (requestId == null) {
      return;
    }

    try {
      var permission =
          await Geolocator
              .checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator
                .requestPermission();
      }

      if (permission ==
              LocationPermission.denied ||
          permission ==
              LocationPermission
                  .deniedForever) {
        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission is required before sharing your location.',
            ),
          ),
        );

        return;
      }

      final position =
          await Geolocator
              .getCurrentPosition();

      final mapLink =
          'Current location: https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

      await RequestService()
          .sendMessage(
        requestId,
        mapLink,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to share current location.',
          ),
        ),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text =
        controller.text.trim();

    if (text.isEmpty ||
        sendingMessage) {
      return;
    }

    final requestId =
        widget.requestId;

    if (requestId == null) {
      controller.clear();

      setState(() {
        messages.add(text);
        senderIds.add('local-me');
        messageImages.add(null);
        messageTimes.add(
          DateTime.now(),
        );
      });

      WidgetsBinding.instance
          .addPostFrameCallback(
        (_) {
          _scrollLatest();
        },
      );

      return;
    }

    setState(() {
      sendingMessage = true;
    });

    try {
      await RequestService()
          .sendMessage(
        requestId,
        text,
      );

      if (mounted) {
        controller.clear();
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
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
      return senderIds[index] ==
          'local-me';
    }

    return senderIds[index] ==
        FirebaseAuth
            .instance.currentUser?.uid;
  }

  bool _showDateSeparator(
    int index,
  ) {
    if (index < 0 ||
        index >=
            messageTimes.length) {
      return false;
    }

    final current =
        messageTimes[index];

    if (current == null) {
      return false;
    }

    if (index == 0) {
      return true;
    }

    final previous =
        messageTimes[index - 1];

    if (previous == null) {
      return true;
    }

    return current.year !=
            previous.year ||
        current.month !=
            previous.month ||
        current.day != previous.day;
  }

  String _dateLabel(
    DateTime value,
  ) {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final date = DateTime(
      value.year,
      value.month,
      value.day,
    );

    final days =
        today.difference(date).inDays;

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

    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  String _timeLabel(
    DateTime? value,
  ) {
    if (value == null) {
      return '';
    }

    final hour =
        value.hour % 12 == 0
            ? 12
            : value.hour % 12;

    final minute = value.minute
        .toString()
        .padLeft(
          2,
          '0',
        );

    final period =
        value.hour >= 12
            ? 'PM'
            : 'AM';

    return '$hour:$minute $period';
  }

  Widget _jobContext() {
    final requestId =
        widget.requestId;

    if (requestId == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<
        DocumentSnapshot<
            Map<String, dynamic>>>(
      stream: RequestService()
          .watchRequest(
        requestId,
      ),
      builder: (
        context,
        snapshot,
      ) {
        final data =
            snapshot.data?.data();

        if (data == null) {
          return const SizedBox
              .shrink();
        }

        final vehicle = [
          data['modelYear']
                  as String? ??
              '',
          data['registration']
                  as String? ??
              '',
        ]
            .where(
              (value) => value
                  .trim()
                  .isNotEmpty,
            )
            .join(' • ');

        return _RaChatJobCard(
          issue:
              requestIssueLabel(data),
          status:
              data['status'] as String? ??
                  '',
          vehicle: vehicle,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return RaScaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 70,
        titleSpacing: 4,
        title: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ProfileInitials(
                  name: widget.peerName,
                  radius: 20,
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration:
                        BoxDecoration(
                      color: raSuccess,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            colors.surface,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.peerName,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: GoogleFonts
                        .plusJakartaSans(
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          colors.onSurface,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    'RoadAssist conversation',
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: GoogleFonts
                        .plusJakartaSans(
                      fontSize: 8.5,
                      color: colors
                          .onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (widget.peerPhone
              .trim()
              .isNotEmpty)
            IconButton(
              tooltip:
                  'Call ${widget.peerName}',
              onPressed: () {
                showCallPrompt(
                  context,
                  name: widget.peerName,
                  number:
                      widget.peerPhone,
                );
              },
              icon: const Icon(
                Icons.call_outlined,
              ),
            ),

          const SizedBox(width: 5),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _jobContext(),

            Expanded(
              child: messages.isEmpty
                  ? _RaChatEmpty(
                      peerName:
                          widget.peerName,
                    )
                  : ListView.builder(
                      controller:
                          scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior
                              .onDrag,
                      padding:
                          const EdgeInsets
                              .fromLTRB(
                        16,
                        15,
                        16,
                        20,
                      ),
                      itemCount:
                          messages.length,
                      itemBuilder: (
                        context,
                        index,
                      ) {
                        final mine =
                            _isMine(
                          index,
                        );

                        final date = index <
                                messageTimes
                                    .length
                            ? messageTimes[
                                index]
                            : null;

                        final image = index <
                                messageImages
                                    .length
                            ? messageImages[
                                index]
                            : null;

                        return Column(
                          children: [
                            if (_showDateSeparator(
                                  index,
                                ) &&
                                date !=
                                    null)
                              _RaChatDateDivider(
                                label:
                                    _dateLabel(
                                  date,
                                ),
                              ),

                            _RaChatBubble(
                              text:
                                  messages[index],
                              imageData:
                                  image,
                              mine: mine,
                              time:
                                  _timeLabel(
                                date,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),

            _RaChatComposer(
              controller: controller,
              busy: sendingMessage,
              attaching:
                  attachingPhoto,
              canAttach:
                  widget.requestId != null,
              onAttach:
                  _openAttachmentSheet,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

enum _RaChatAttachmentAction {
  gallery,
  camera,
  location,
}

class _RaChatJobCard
    extends StatelessWidget {
  const _RaChatJobCard({
    required this.issue,
    required this.status,
    required this.vehicle,
  });

  final String issue;
  final String status;
  final String vehicle;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    final label = switch (status) {
      'searching' => 'Searching',
      'accepted' => 'Accepted',
      'en_route' => 'En route',
      'arrived' => 'Arrived',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => status.replaceAll('_', ' '),
    };

    final tone = switch (status) {
      'completed' => RaTone.success,
      'cancelled' => RaTone.danger,
      'accepted' ||
      'en_route' ||
      'arrived' =>
        RaTone.success,
      _ => RaTone.info,
    };

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        10,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(
            color: colors
                .outlineVariant
                .withValues(alpha: .45),
          ),
        ),
      ),
      child: Container(
        padding:
            const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.primary
              .withValues(alpha: .055),
          borderRadius:
              BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration:
                  BoxDecoration(
                color: colors.primary
                    .withValues(
                  alpha: .10,
                ),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: Icon(
                Icons
                    .car_repair_outlined,
                size: 18,
                color: colors.primary,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    issue,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: GoogleFonts
                        .plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  if (vehicle
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      vehicle,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 8.5,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 7),

            StatusPill(
              label: label,
              tone: tone,
            ),
          ],
        ),
      ),
    );
  }
}

class _RaChatAttachmentTile
    extends StatelessWidget {
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
    final colors =
        Theme.of(context).colorScheme;

    return Material(
      color: colors
          .surfaceContainerHighest
          .withValues(alpha: .33),
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
                width: 40,
                height: 40,
                decoration:
                    BoxDecoration(
                  color: colors.primary
                      .withValues(
                    alpha: .08,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
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
                        fontSize: 10.8,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 8.7,
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

class _RaChatDateDivider
    extends StatelessWidget {
  const _RaChatDateDivider({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: colors
                  .outlineVariant
                  .withValues(alpha: .55),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 10,
            ),
            child: Text(
              label,
              style: GoogleFonts
                  .plusJakartaSans(
                fontSize: 8.5,
                fontWeight:
                    FontWeight.w600,
                color: colors
                    .onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: colors
                  .outlineVariant
                  .withValues(alpha: .55),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaChatBubble extends StatelessWidget {
  const _RaChatBubble({
    required this.text,
    required this.imageData,
    required this.mine,
    required this.time,
  });

  final String text;
  final String? imageData;
  final bool mine;
  final String time;

  bool get isLocation =>
      text.startsWith(
        'Current location: http://',
      ) ||
      text.startsWith(
        'Current location: https://',
      );

  String get locationUrl => isLocation
      ? text
          .substring(
            'Current location: '.length,
          )
          .trim()
      : '';

  Future<void> openLocation(
    BuildContext context,
  ) async {
    final uri =
        Uri.tryParse(locationUrl);

    if (uri == null) return;

    final opened = await launchUrl(
      uri,
      mode:
          LaunchMode.externalApplication,
    );

    if (!opened &&
        context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open the shared location.',
          ),
        ),
      );
    }
  }

  void openImage(
    BuildContext context,
    String data,
  ) {
    try {
      final bytes =
          base64Decode(data);

      showDialog<void>(
        context: context,
        barrierColor: Colors.black
            .withValues(alpha: .90),
        builder: (
          dialogContext,
        ) {
          return Dialog.fullscreen(
            backgroundColor:
                Colors.black,
            child: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child:
                        InteractiveViewer(
                      minScale: .8,
                      maxScale: 4,
                      child: Image.memory(
                        bytes,
                        fit:
                            BoxFit.contain,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child:
                        IconButton.filled(
                      style: IconButton
                          .styleFrom(
                        backgroundColor:
                            Colors.white
                                .withValues(
                          alpha: .14,
                        ),
                        foregroundColor:
                            Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pop(
                          dialogContext,
                        );
                      },
                      icon: const Icon(
                        Icons
                            .close_rounded,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } on FormatException {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'This photo could not be displayed.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final bubbleColor = mine
        ? colors.primary
        : theme.brightness ==
                Brightness.dark
            ? const Color(0xFF122435)
            : Colors.white;

    return Align(
      alignment: mine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.sizeOf(context)
                      .width *
                  .76,
        ),
        margin:
            const EdgeInsets.only(
          bottom: 7,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius:
              BorderRadius.only(
            topLeft:
                const Radius.circular(
              19,
            ),
            topRight:
                const Radius.circular(
              19,
            ),
            bottomLeft:
                Radius.circular(
              mine ? 19 : 5,
            ),
            bottomRight:
                Radius.circular(
              mine ? 5 : 19,
            ),
          ),
          border: mine
              ? null
              : Border.all(
                  color: colors
                      .outlineVariant
                      .withValues(
                    alpha: .43,
                  ),
                ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            if (imageData != null &&
                imageData!.isNotEmpty)
              GestureDetector(
                onTap: () {
                  openImage(
                    context,
                    imageData!,
                  );
                },
                child:
                    _RaChatImageMessage(
                  data: imageData!,
                ),
              )
            else if (isLocation)
              InkWell(
                onTap: () {
                  openLocation(
                    context,
                  );
                },
                child:
                    _RaChatLocationMessage(
                  mine: mine,
                ),
              )
            else
              Padding(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  13,
                  10,
                  13,
                  7,
                ),
                child: Text(
                  text,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 10.5,
                    height: 1.4,
                    color: mine
                        ? colors.onPrimary
                        : colors.onSurface,
                  ),
                ),
              ),

            if (time.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  13,
                  3,
                  13,
                  7,
                ),
                child: Text(
                  time,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 7.5,
                    color: mine
                        ? colors.onPrimary
                            .withValues(
                            alpha: .68,
                          )
                        : colors
                            .onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RaChatImageMessage
    extends StatelessWidget {
  const _RaChatImageMessage({
    required this.data,
  });

  final String data;

  @override
  Widget build(BuildContext context) {
    try {
      return Image.memory(
        base64Decode(data),
        width: 245,
        height: 185,
        fit: BoxFit.cover,
        errorBuilder: (
          _,
          __,
          ___,
        ) =>
            const SizedBox(
          width: 245,
          height: 150,
          child: Center(
            child: Icon(
              Icons
                  .broken_image_outlined,
            ),
          ),
        ),
      );
    } on FormatException {
      return const SizedBox(
        width: 245,
        height: 150,
        child: Center(
          child: Icon(
            Icons
                .broken_image_outlined,
          ),
        ),
      );
    }
  }
}

class _RaChatLocationMessage
    extends StatelessWidget {
  const _RaChatLocationMessage({
    required this.mine,
  });

  final bool mine;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    final foreground = mine
        ? colors.onPrimary
        : colors.onSurface;

    final secondary = mine
        ? colors.onPrimary
            .withValues(alpha: .72)
        : colors.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: mine
                  ? Colors.white
                      .withValues(alpha: .13)
                  : colors.primary
                      .withValues(alpha: .08),
              borderRadius:
                  BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: mine
                  ? colors.onPrimary
                  : colors.primary,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Shared location',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight:
                        FontWeight.w700,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap to open in Maps',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 8.5,
                    color: secondary,
                  ),
                ),
              ],
            ),
          ),

          Icon(
            Icons.open_in_new_rounded,
            size: 16,
            color: secondary,
          ),
        ],
      ),
    );
  }
}

class _RaChatEmpty
    extends StatelessWidget {
  const _RaChatEmpty({
    required this.peerName,
  });

  final String peerName;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding:
            const EdgeInsets.all(25),
        child: Column(
          children: [
            Container(
              width: 74,
              height: 74,
              decoration:
                  BoxDecoration(
                color: colors.primary
                    .withValues(
                  alpha: .08,
                ),
                borderRadius:
                    BorderRadius.circular(
                  24,
                ),
              ),
              child: Icon(
                Icons.forum_outlined,
                color: colors.primary,
                size: 33,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Start the conversation',
              textAlign:
                  TextAlign.center,
              style: GoogleFonts
                  .plusJakartaSans(
                fontSize: 17,
                fontWeight:
                    FontWeight.w800,
                color: colors.onSurface,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              'Message $peerName about this roadside assistance job. You can also share photos or your current location.',
              textAlign:
                  TextAlign.center,
              style: GoogleFonts
                  .plusJakartaSans(
                fontSize: 10,
                height: 1.5,
                color: colors
                    .onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RaChatComposer
    extends StatelessWidget {
  const _RaChatComposer({
    required this.controller,
    required this.busy,
    required this.attaching,
    required this.canAttach,
    required this.onAttach,
    required this.onSend,
  });

  final TextEditingController controller;

  final bool busy;
  final bool attaching;
  final bool canAttach;

  final VoidCallback onAttach;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    final hasText =
        controller.text.trim().isNotEmpty;

    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        8,
        8,
        8,
        11,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(
            color: colors
                .outlineVariant
                .withValues(alpha: .45),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.end,
          children: [
            IconButton.filledTonal(
              tooltip: 'Attach',
              onPressed: canAttach &&
                      !attaching
                  ? onAttach
                  : null,
              icon: attaching
                  ? const SizedBox.square(
                      dimension: 17,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.add_rounded,
                    ),
            ),

            const SizedBox(width: 7),

            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization:
                    TextCapitalization
                        .sentences,
                decoration:
                    InputDecoration(
                  hintText:
                      'Message…',
                  filled: true,
                  fillColor: colors
                      .surfaceContainerHighest
                      .withValues(
                    alpha: .40,
                  ),
                  contentPadding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 15,
                    vertical: 11,
                  ),
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      22,
                    ),
                    borderSide:
                        BorderSide.none,
                  ),
                  enabledBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      22,
                    ),
                    borderSide:
                        BorderSide.none,
                  ),
                  focusedBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      22,
                    ),
                    borderSide:
                        BorderSide(
                      color: colors.primary
                          .withValues(
                        alpha: .35,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 7),

            IconButton.filled(
              tooltip: 'Send',
              onPressed: hasText &&
                      !busy
                  ? () {
                      unawaited(
                        onSend(),
                      );
                    }
                  : null,
              icon: busy
                  ? SizedBox.square(
                      dimension: 17,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors
                            .onPrimary,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}