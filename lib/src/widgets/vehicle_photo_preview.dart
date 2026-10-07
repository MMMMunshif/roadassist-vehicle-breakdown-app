part of '../screens.dart';

class VehiclePhotoPreview extends StatefulWidget {
  const VehiclePhotoPreview({
    super.key,
    required this.model,
    this.photoData = '',
    this.height = 185,
    this.compact = false,
  });
  final String model, photoData;
  final double height;
  final bool compact;
  @override
  State<VehiclePhotoPreview> createState() => _VehiclePhotoPreviewState();
}

class _VehiclePhotoPreviewState extends State<VehiclePhotoPreview> {
  Future<VehicleReferencePhoto?>? lookup;
  Timer? debounce;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void didUpdateWidget(VehiclePhotoPreview old) {
    super.didUpdateWidget(old);
    if (old.model != widget.model || old.photoData != widget.photoData)
      refresh();
  }

  void refresh() {
    debounce?.cancel();
    lookup = null;
    if (widget.photoData.isNotEmpty ||
        VehicleImageService.modelQuery(widget.model).isEmpty)
      return;
    debounce = Timer(const Duration(milliseconds: 700), () {
      if (mounted)
        setState(() {
          lookup = VehicleImageService.shared.lookup(widget.model);
        });
    });
  }

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  Widget fallback() => widget.compact
      ? SizedBox(
          height: widget.height,
          child: const Center(
            child: Icon(Icons.directions_car_outlined, size: 44),
          ),
        )
      : SizedBox(
          height: widget.height,
          width: double.infinity,
          child: const SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_car, size: 48),
                Text('Enter make and model, or add your vehicle photo.'),
                Text('Reference photo may be unavailable offline.'),
              ],
            ),
          ),
        );
  Widget frame(
    Widget image,
    String label, {
    VehicleReferencePhoto? reference,
  }) => widget.compact
      ? SizedBox(
          height: widget.height,
          child: Stack(
            children: [
              Positioned.fill(child: image),
              Positioned(
                right: 0,
                bottom: 0,
                child: Tooltip(
                  message: label,
                  child: IconButton(
                    iconSize: 16,
                    visualDensity: VisualDensity.compact,
                    tooltip: reference == null
                        ? label
                        : 'Photo: ${reference.credit}. $label',
                    onPressed: reference == null
                        ? null
                        : () => launchUrl(
                            Uri.parse(reference.source),
                            mode: LaunchMode.externalApplication,
                          ),
                    icon: const Icon(Icons.info_outline),
                  ),
                ),
              ),
            ],
          ),
        )
      : Column(
          children: [
            SizedBox(
              height: widget.height,
              width: double.infinity,
              child: image,
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(label, textAlign: TextAlign.center),
            ),
            if (reference != null)
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(reference.source),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(
                  'Photo: ${reference.credit}',
                  maxLines: 3,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        );
  @override
  Widget build(BuildContext context) {
    if (widget.photoData.isNotEmpty) {
      try {
        return frame(
          Image.memory(
            base64Decode(widget.photoData),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => fallback(),
          ),
          'Driver-provided vehicle photo',
        );
      } on FormatException {
        return fallback();
      }
    }
    return FutureBuilder<VehicleReferencePhoto?>(
      key: ValueKey(widget.model),
      future: lookup,
      builder: (context, snapshot) {
        final photo = snapshot.data;
        if (photo == null) return fallback();
        return frame(
          Image.network(
            photo.url,
            fit: BoxFit.contain,
            webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
            errorBuilder: (_, _, _) => fallback(),
          ),
          'Model reference photo - not the driver\'s actual vehicle. ${photo.exactYear ? 'Filename matches entered year; confirm variant.' : 'Year / generation may differ.'}',
          reference: photo,
        );
      },
    );
  }
}

String requestVehiclePhoto(Map<String, dynamic> data) {
  final uploaded = (data['vehiclePhotoUrls'] as List? ?? [])
      .whereType<String>();
  if (uploaded.isNotEmpty) return uploaded.first;
  return (data['vehicleSnapshot'] as Map?)?['photoData'] as String? ?? '';
}
