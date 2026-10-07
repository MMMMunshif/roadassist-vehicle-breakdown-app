part of '../../screens.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({
    super.key,
  });

  @override
  State<CameraCaptureScreen> createState() =>
      _CameraCaptureScreenState();
}

class _CameraCaptureScreenState
    extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? controller;

  String? errorMessage;

  bool capturing = false;
  bool initializing = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(
      this,
    );

    initializeCamera();
  }

  Future<void> initializeCamera() async {
    if (mounted) {
      setState(() {
        errorMessage = null;
        initializing = true;
      });
    }

    try {
      final cameras =
          await availableCameras();

      if (cameras.isEmpty) {
        throw CameraException(
          'noCamera',
          'No camera was found on this device.',
        );
      }

      final selected =
          cameras.firstWhere(
        (camera) =>
            camera.lensDirection ==
            CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final next =
          CameraController(
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

      setState(() {
        controller = next;
        initializing = false;
      });
    } on CameraException catch (error) {
      if (!mounted) return;

      setState(() {
        initializing = false;
        errorMessage =
            error.description ??
            'Camera access is unavailable.';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        initializing = false;
        errorMessage = '$error';
      });
    }
  }

  Future<void> capture() async {
    final active = controller;

    if (active == null ||
        !active.value.isInitialized ||
        capturing) {
      return;
    }

    setState(() {
      capturing = true;
    });

    try {
      final photo =
          await active.takePicture();

      if (!mounted) return;

      Navigator.pop(
        context,
        photo,
      );
    } on CameraException catch (error) {
      if (!mounted) return;

      setState(() {
        capturing = false;
        errorMessage =
            error.description ??
            'Unable to capture the photo.';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state ==
        AppLifecycleState.inactive) {
      final previous = controller;

      controller = null;

      previous?.dispose();
    } else if (state ==
            AppLifecycleState.resumed &&
        controller == null) {
      initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(
      this,
    );

    controller?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Take a Photo',
        ),
        backgroundColor:
            Colors.black,
        foregroundColor:
            Colors.white,
      ),
      body: SafeArea(
        top: false,
        child: errorMessage != null
            ? _CameraCaptureError(
                message: errorMessage!,
                onRetry:
                    initializeCamera,
              )
            : initializing ||
                    controller == null ||
                    !controller!
                        .value
                        .isInitialized
            ? const _CameraCaptureLoading()
            : Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: CameraPreview(
                      controller!,
                    ),
                  ),

                  IgnorePointer(
                    child: Container(
                      decoration:
                          BoxDecoration(
                        gradient:
                            LinearGradient(
                          begin: Alignment
                              .topCenter,
                          end: Alignment
                              .bottomCenter,
                          colors: [
                            Colors.black
                                .withValues(
                              alpha: .30,
                            ),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black
                                .withValues(
                              alpha: .56,
                            ),
                          ],
                          stops: const [
                            0,
                            .22,
                            .62,
                            1,
                          ],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 22,
                    left: 24,
                    right: 24,
                    child: Center(
                      child: Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration:
                            BoxDecoration(
                          color: Colors.black
                              .withValues(
                            alpha: .44,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            999,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            Icon(
                              Icons
                                  .center_focus_strong_outlined,
                              color:
                                  Colors.white,
                              size: 17,
                            ),
                            SizedBox(
                              width: 7,
                            ),
                            Flexible(
                              child: Text(
                                'Keep the subject clear and inside the frame',
                                style: TextStyle(
                                  color:
                                      Colors.white,
                                  fontSize: 11.5,
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Center(
                    child: Container(
                      width: 270,
                      height: 340,
                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius
                                .circular(
                          26,
                        ),
                        border: Border.all(
                          color: Colors.white
                              .withValues(
                            alpha: .66,
                          ),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 22,
                    child: Column(
                      children: [
                        Text(
                          capturing
                              ? 'Capturing…'
                              : 'Tap to capture',
                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontSize: 13,
                            fontWeight:
                                FontWeight
                                    .w700,
                          ),
                        ),

                        const SizedBox(
                          height: 13,
                        ),

                        Container(
                          width: 82,
                          height: 82,
                          padding:
                              const EdgeInsets
                                  .all(
                            5,
                          ),
                          decoration:
                              BoxDecoration(
                            shape:
                                BoxShape.circle,
                            border:
                                Border.all(
                              color: Colors.white
                                  .withValues(
                                alpha: .9,
                              ),
                              width: 3,
                            ),
                          ),
                          child:
                              IconButton.filled(
                            onPressed:
                                capturing
                                ? null
                                : capture,
                            style: IconButton
                                .styleFrom(
                              backgroundColor:
                                  Colors.white,
                              foregroundColor:
                                  raBlue,
                              disabledBackgroundColor:
                                  Colors.white
                                      .withValues(
                                alpha: .65,
                              ),
                              disabledForegroundColor:
                                  raBlue,
                            ),
                            icon: capturing
                                ? const SizedBox.square(
                                    dimension:
                                        24,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          3,
                                    ),
                                  )
                                : const Icon(
                                    Icons
                                        .camera_alt_rounded,
                                    size: 31,
                                  ),
                          ),
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        Text(
                          'Make sure the image is readable before continuing.',
                          textAlign:
                              TextAlign.center,
                          style:
                              TextStyle(
                            color: Colors.white
                                .withValues(
                              alpha: .72,
                            ),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CameraCaptureLoading
    extends StatelessWidget {
  const _CameraCaptureLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: Colors.white,
          ),
          SizedBox(height: 18),
          Text(
            'Starting camera…',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraCaptureError
    extends StatelessWidget {
  const _CameraCaptureError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(
          RaSpace.xl,
        ),
        child: Container(
          constraints:
              const BoxConstraints(
            maxWidth: 390,
          ),
          padding: const EdgeInsets.all(
            RaSpace.xl,
          ),
          decoration: BoxDecoration(
            color: const Color(
              0xFF171717,
            ),
            borderRadius:
                BorderRadius.circular(
              24,
            ),
            border: Border.all(
              color: Colors.white
                  .withValues(
                alpha: .10,
              ),
            ),
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha: .08,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    24,
                  ),
                ),
                child: const Icon(
                  Icons
                      .no_photography_outlined,
                  color: Colors.white,
                  size: 36,
                ),
              ),

              const SizedBox(
                height: RaSpace.lg,
              ),

              const Text(
                'Camera unavailable',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(
                height: RaSpace.sm,
              ),

              Text(
                message,
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color: Colors.white
                      .withValues(
                    alpha: .72,
                  ),
                  height: 1.45,
                ),
              ),

              const SizedBox(
                height: RaSpace.xl,
              ),

              SizedBox(
                width:
                    double.infinity,
                child:
                    FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(
                    Icons
                        .refresh_rounded,
                  ),
                  label:
                      const Text(
                    'Try Again',
                  ),
                ),
              ),

              const SizedBox(
                height: RaSpace.sm,
              ),

              TextButton(
                onPressed: () =>
                    Navigator.pop(
                  context,
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color:
                        Colors.white,
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