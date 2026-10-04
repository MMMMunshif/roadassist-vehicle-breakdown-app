part of '../screens.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? controller;
  String? errorMessage;
  bool capturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    setState(() => errorMessage = null);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty)
        throw CameraException(
          'noCamera',
          'No camera was found on this device.',
        );
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final next = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await next.initialize();
      await controller?.dispose();
      if (!mounted) {
        await next.dispose();
        return;
      }
      setState(() => controller = next);
    } on CameraException catch (error) {
      if (mounted) {
        setState(
          () => errorMessage =
              error.description ?? 'Camera permission was denied.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => errorMessage = '$error');
    }
  }

  Future<void> capture() async {
    final active = controller;
    if (active == null || !active.value.isInitialized || capturing) return;
    setState(() => capturing = true);
    try {
      final photo = await active.takePicture();
      if (mounted) Navigator.pop(context, photo);
    } on CameraException catch (error) {
      if (mounted) {
        setState(() {
          capturing = false;
          errorMessage = error.description ?? 'Unable to capture the photo.';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      controller?.dispose();
      controller = null;
    } else if (state == AppLifecycleState.resumed && controller == null) {
      initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: const Text('Take a Photo'),
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
    ),
    body: errorMessage != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(RaSpace.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.no_photography_outlined,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: RaSpace.md),
                  Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: RaSpace.lg),
                  FilledButton.icon(
                    onPressed: initializeCamera,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          )
        : controller == null || !controller!.value.isInitialized
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : Stack(
            fit: StackFit.expand,
            children: [
              Center(child: CameraPreview(controller!)),
              Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: Center(
                  child: IconButton.filled(
                    onPressed: capturing ? null : capture,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: raBlue,
                      fixedSize: const Size(68, 68),
                    ),
                    icon: capturing
                        ? const CircularProgressIndicator(strokeWidth: 3)
                        : const Icon(Icons.camera_alt, size: 31),
                  ),
                ),
              ),
            ],
          ),
  );
}
