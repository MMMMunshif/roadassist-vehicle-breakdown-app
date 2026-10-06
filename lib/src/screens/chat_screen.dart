part of '../screens.dart';

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
      // The provider can still enter a manual travel charge without GPS.
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
  int warrantyDays = 0;
  final evidence = <String>[];
  bool preparingPhoto = false;
  String? evidenceError;
  bool inspectionOnly = false;

  int amount(TextEditingController controller) =>
      int.tryParse(controller.text.replaceAll(',', '').trim()) ?? 0;

  final quoteRoute = DialogRoute<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
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
        Future<void> attachEvidence(ImageSource source) async {
          if (preparingPhoto || evidence.length >= 2) return;
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
            if (dialogContext.mounted)
              setDialogState(() => evidence.add(encoded));
          } catch (_) {
            if (dialogContext.mounted)
              setDialogState(
                () => evidenceError =
                    'Could not prepare the photo. Choose a supported image and try again.',
              );
          } finally {
            if (dialogContext.mounted)
              setDialogState(() => preparingPhoto = false);
          }
        }

        Widget moneyField(String label, TextEditingController controller) =>
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(7),
              ],
              onChanged: (_) => setDialogState(() {}),
              decoration: InputDecoration(labelText: label, prefixText: 'Rs. '),
            );
        return AlertDialog(
          icon: const Icon(Icons.request_quote_outlined, color: raBlue),
          title: const Text('Review and quote request'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${requestData['issue'] ?? 'Roadside assistance'} - ${distanceKm > 0 ? '${distanceKm.toStringAsFixed(1)} km away' : 'distance unavailable'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: RaSpace.md),
                Text('Vehicle: ${requestData['modelYear'] ?? ''}'),
                VehiclePhotoPreview(
                  model: requestData['modelYear'] as String? ?? '',
                  photoData: requestVehiclePhoto(requestData),
                  height: 130,
                ),
                const Text(
                  'Confirm year, engine / variant and part number before choosing parts.',
                ),
                Text('Driver symptoms: ${requestData['description'] ?? ''}'),
                Text(
                  'Parts preference: ${requestData['partsPreference'] ?? 'discuss'}',
                ),
                if (requestData['workflowVersion'] == 2 &&
                    requestData['repairRevision'] != true)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Inspection required'),
                    subtitle: const Text(
                      'Quote covers the visit and inspection only. Repair needs a separate approved quote.',
                    ),
                    value: inspectionOnly,
                    onChanged: (v) => setDialogState(() => inspectionOnly = v),
                  ),
                if (requestData['repairRevision'] == true) ...[
                  Text(
                    'Previously approved: Rs. ${requestData['estimatedCost'] ?? 0}',
                  ),
                  const Text(
                    'Enter the full replacement bill, including previously approved work. Explain the new problem, added work and parts. Wait for driver approval before starting it.',
                  ),
                ],
                moneyField(
                  inspectionOnly
                      ? 'Visit / inspection charge'
                      : 'Service / labour charge',
                  serviceController,
                ),
                const SizedBox(height: RaSpace.sm),
                moneyField('Travel / distance charge', travelController),
                const SizedBox(height: RaSpace.sm),
                moneyField('Extra charge', extraController),
                const SizedBox(height: RaSpace.sm),
                TextField(
                  controller: notesController,
                  onChanged: (_) => setDialogState(() {}),
                  maxLength: 200,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Included work, parts and exclusions',
                    hintText: 'Parts, after-hours fee, or other details',
                  ),
                ),
                DropdownButtonFormField<int>(
                  initialValue: warrantyDays,
                  decoration: const InputDecoration(
                    labelText: 'Service warranty',
                  ),
                  items: [0, 7, 14, 30, 90, 180, 365]
                      .map(
                        (days) => DropdownMenuItem(
                          value: days,
                          child: Text(
                            days == 0 ? 'No service warranty' : '$days days',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: inspectionOnly
                      ? null
                      : (value) => setDialogState(() => warrantyDays = value!),
                ),
                if (warrantyDays > 0 && !inspectionOnly)
                  TextField(
                    controller: warrantyController,
                    maxLength: 500,
                    maxLines: 3,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Covered work and exclusions',
                      hintText:
                          'State which repair is covered, parts/labour and any travel charge.',
                    ),
                  ),
                const Text(
                  'Warranty starts when the driver confirms completion. It covers only the stated work.',
                ),
                if (revision) ...[
                  TextField(
                    controller: reasonController,
                    maxLength: 300,
                    maxLines: 3,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Reason for price / work change',
                      hintText:
                          'Explain what was discovered and why this change is needed.',
                    ),
                  ),
                  const Text(
                    'Photo evidence: required for a price increase. Show the damaged part, repair or parts receipt.',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: preparingPhoto || evidence.length >= 2
                            ? null
                            : () => attachEvidence(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Add photo'),
                      ),
                      OutlinedButton.icon(
                        onPressed: preparingPhoto || evidence.length >= 2
                            ? null
                            : () => attachEvidence(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Take photo'),
                      ),
                    ],
                  ),
                  for (var i = 0; i < evidence.length; i++)
                    Row(
                      children: [
                        Expanded(
                          child: Image.memory(
                            base64Decode(evidence[i]),
                            height: 100,
                            fit: BoxFit.contain,
                          ),
                        ),
                        IconButton(
                          onPressed: preparingPhoto
                              ? null
                              : () =>
                                    setDialogState(() => evidence.removeAt(i)),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove evidence photo',
                        ),
                      ],
                    ),
                  if (preparingPhoto) const LinearProgressIndicator(),
                  if (evidenceError != null) Text(evidenceError!),
                  if (revisionError != null) Text(revisionError),
                ],
                Container(
                  padding: const EdgeInsets.all(RaSpace.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(RaRadius.sm),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        requestData['repairRevision'] == true
                            ? 'New full total'
                            : 'Quoted total',
                        style: RaText.label,
                      ),
                      Text('Rs. $total', style: RaText.title),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed:
                  (revision ? total < 0 : total <= 0) ||
                      preparingPhoto ||
                      (!inspectionOnly &&
                          warrantyDays > 0 &&
                          warrantyController.text.trim().length < 10) ||
                      revisionError != null ||
                      total > 10000000 ||
                      (requestData['workflowVersion'] == 2 &&
                          notesController.text.trim().isEmpty)
                  ? null
                  : () => Navigator.pop(dialogContext, {
                      'serviceFee': amount(serviceController),
                      'travelFee': amount(travelController),
                      'extraFee': amount(extraController),
                      'providerDistanceKm': distanceKm,
                      'quoteNotes': notesController.text.trim(),
                      'quoteType': inspectionOnly ? 'inspection' : 'direct',
                      'warrantyDays': inspectionOnly ? 0 : warrantyDays,
                      'warrantyTerms': inspectionOnly || warrantyDays == 0
                          ? ''
                          : warrantyController.text.trim(),
                      if (revision)
                        'changeReason': reasonController.text.trim(),
                      if (revision)
                        'evidencePhotoData': List<String>.from(evidence),
                    }),
              child: Text(
                requestData['workflowVersion'] == 2
                    ? 'Send Offer'
                    : 'Accept with Quote',
              ),
            ),
          ],
        );
      },
    ),
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

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final controller = TextEditingController();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? messageListener;
  final messages = <String>[];
  final senderIds = <String>[];
  final messageImages = <String?>[];
  bool attachingPhoto = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    messageListener?.cancel();
    controller.dispose();
    super.dispose();
  }

  Future<void> attachPhoto() async {
    if (widget.requestId == null || attachingPhoto) return;
    final navigator = Navigator.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => const SafeArea(
        child: Wrap(
          children: [
            _PhotoSourceTile(
              icon: Icons.photo_library_outlined,
              label: 'Choose from gallery',
              source: ImageSource.gallery,
            ),
            _PhotoSourceTile(
              icon: Icons.camera_alt_outlined,
              label: 'Take a photo',
              source: ImageSource.camera,
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final photo = source == ImageSource.camera
        ? await navigator.push<XFile>(
            MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
          )
        : await ImagePicker().pickImage(
            source: ImageSource.gallery,
            imageQuality: 75,
            maxWidth: 1400,
          );
    if (photo == null || !mounted) return;
    setState(() => attachingPhoto = true);
    try {
      final imageData = await PhotoUploadService().prepareChatPhoto(photo);
      await RequestService().sendChatPhoto(widget.requestId!, imageData);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to send photo: $error')));
      }
    } finally {
      if (mounted) setState(() => attachingPhoto = false);
    }
  }

  Future<void> shareCurrentLocation() async {
    if (widget.requestId == null) return;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to share current location.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.peerName),
      actions: [
        IconButton(
          onPressed: widget.peerPhone.isEmpty
              ? null
              : () => showCallPrompt(
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
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(RaSpace.xl),
              itemCount: messages.length,
              itemBuilder: (_, index) {
                final mine = widget.requestId == null
                    ? index.isOdd
                    : senderIds[index] ==
                          FirebaseAuth.instance.currentUser?.uid;
                return Align(
                  alignment: mine
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    margin: const EdgeInsets.only(bottom: RaSpace.sm),
                    padding: const EdgeInsets.symmetric(
                      horizontal: RaSpace.md,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: mine ? raBlue : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(RaRadius.sm),
                        topRight: const Radius.circular(RaRadius.sm),
                        bottomLeft: Radius.circular(mine ? RaRadius.sm : 3),
                        bottomRight: Radius.circular(mine ? 3 : RaRadius.sm),
                      ),
                      border: mine ? null : Border.all(color: raLine),
                    ),
                    child: messageImages[index] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(
                              RaRadius.sm - 2,
                            ),
                            child: Image.memory(
                              base64Decode(messageImages[index]!),
                              width: 220,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Text(
                            messages[index],
                            style: TextStyle(
                              color: mine ? Colors.white : raInk,
                              fontSize: 13.5,
                              height: 1.4,
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(
              RaSpace.sm,
              RaSpace.sm,
              RaSpace.sm,
              RaSpace.md,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: raLine)),
            ),
            child: Column(
              children: [
                if (widget.requestId != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ActionChip(
                      avatar: const Icon(Icons.my_location_outlined, size: 16),
                      label: const Text('Share current location'),
                      onPressed: shareCurrentLocation,
                    ),
                  ),
                  const SizedBox(height: RaSpace.xs),
                ],
                Row(
                  children: [
                    IconButton(
                      onPressed: widget.requestId == null || attachingPhoto
                          ? null
                          : attachPhoto,
                      tooltip: 'Attach photo',
                      icon: attachingPhoto
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_a_photo_outlined),
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: RaSpace.xs),
                    IconButton.filled(
                      onPressed: () async {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;
                        controller.clear();
                        if (widget.requestId != null) {
                          await RequestService().sendMessage(
                            widget.requestId!,
                            text,
                          );
                        } else {
                          setState(() {
                            messages.add(text);
                            senderIds.add('driver');
                            messageImages.add(null);
                          });
                        }
                      },
                      tooltip: 'Send',
                      icon: const Icon(Icons.send),
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
}
