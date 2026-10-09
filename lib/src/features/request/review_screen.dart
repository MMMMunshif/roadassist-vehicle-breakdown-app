part of '../../screens.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.draft});

  final RequestDraft draft;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool submitting = false;

  StreamSubscription<List<ConnectivityResult>>? connectivitySubscription;

  bool get readyToSubmit =>
      widget.draft.modelYear.trim().isNotEmpty &&
      widget.draft.registration.trim().isNotEmpty &&
      !widget.draft.location.startsWith('Select current GPS');

  bool get specificProvider =>
      widget.draft.preferredProviderId.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();

    connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
      if (!mounted ||
          results.every((result) => result == ConnectivityResult.none)) {
        return;
      }

      if (await RequestDraftStore().hasPendingSubmission() && mounted) {
        await submitRequest(autoRetry: true);
      }
    });
  }

  @override
  void dispose() {
    connectivitySubscription?.cancel();

    super.dispose();
  }

  Future<void> submitRequest({bool autoRetry = false}) async {
    if (submitting) return;

    if (!readyToSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Complete every required request item before submitting.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );

      return;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please sign in as a driver so providers can receive your request.',
          ),
        ),
      );

      return;
    }

    final connections = await Connectivity().checkConnectivity();

    if (connections.every((result) => result == ConnectivityResult.none)) {
      await RequestDraftStore().save(widget.draft);

      await RequestDraftStore().setPendingSubmission(true);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You are offline. Your request has been saved and will retry when connected.',
          ),
        ),
      );

      return;
    }

    setState(() {
      submitting = true;
    });

    try {
      final requestId = await RequestService().createRequest(widget.draft);

      await RequestDraftStore().clear();

      if (!mounted) return;

      await showSafetyChecklist();

      if (!mounted) return;

      replace(
        context,
        SearchingScreen(draft: widget.draft, requestId: requestId),
      );
    } catch (error) {
      if (!mounted) return;

      final activeRequestExists = error.toString().contains(
        'Complete or cancel your active request',
      );

      final networkError =
          error is FirebaseException &&
          const [
            'unavailable',
            'deadline-exceeded',
            'network-request-failed',
          ].contains(error.code);

      if (networkError) {
        await RequestDraftStore().save(widget.draft);

        await RequestDraftStore().setPendingSubmission(true);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            activeRequestExists
                ? 'Complete or cancel your current request before creating another.'
                : networkError
                ? 'Connection lost. Your request has been saved and will retry automatically.'
                : 'Unable to create the request. Please try again.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: activeRequestExists
              ? SnackBarAction(
                  label: 'OPEN REQUEST',
                  textColor: Colors.white,
                  onPressed: () {
                    push(context, const HistoryScreen());
                  },
                )
              : null,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          submitting = false;
        });
      }
    }
  }

  Future<void> showSafetyChecklist() async {
    bool vehicleSafe = false;
    bool hazardsOn = false;
    bool passengersSafe = false;
    bool emergencyRequired = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);

            final colors = theme.colorScheme;

            return AlertDialog(
              icon: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.health_and_safety_outlined,
                  color: colors.primary,
                  size: 28,
                ),
              ),
              title: const Text('Stay safe while you wait'),
              content: SizedBox(
                width: 430,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Check the items that apply to your roadside situation.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        height: 1.4,
                        color: colors.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 14),

                    _RaReviewSafetyTile(
                      icon: Icons.directions_car_outlined,
                      title: 'Vehicle is in a safe place',
                      value: vehicleSafe,
                      onChanged: (value) {
                        setDialogState(() {
                          vehicleSafe = value;
                        });
                      },
                    ),

                    const SizedBox(height: 8),

                    _RaReviewSafetyTile(
                      icon: Icons.warning_amber_rounded,
                      title: 'Hazard lights are on',
                      value: hazardsOn,
                      onChanged: (value) {
                        setDialogState(() {
                          hazardsOn = value;
                        });
                      },
                    ),

                    const SizedBox(height: 8),

                    _RaReviewSafetyTile(
                      icon: Icons.groups_outlined,
                      title: 'Passengers are safe',
                      value: passengersSafe,
                      onChanged: (value) {
                        setDialogState(() {
                          passengersSafe = value;
                        });
                      },
                    ),

                    const SizedBox(height: 8),

                    _RaReviewSafetyTile(
                      icon: Icons.emergency_outlined,
                      title: 'Immediate emergency help is required',
                      value: emergencyRequired,
                      danger: true,
                      onChanged: (value) {
                        setDialogState(() {
                          emergencyRequired = value;
                        });
                      },
                    ),

                    if (emergencyRequired) ...[
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.error,
                            foregroundColor: colors.onError,
                          ),
                          onPressed: () {
                            showCallPrompt(
                              dialogContext,
                              name: 'Police Emergency',
                              number: '119',
                            );
                          },
                          icon: const Icon(Icons.call_rounded),
                          label: const Text('Call 119'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  icon: const Icon(Icons.navigation_outlined),
                  label: const Text('Continue to Provider Search'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String partsPreferenceLabel(String value) {
    return switch (value) {
      'budget' => 'Budget compatible',
      'branded' => 'Branded aftermarket',
      'genuine' => 'Genuine manufacturer parts',
      _ => 'Discuss options with provider',
    };
  }

  BreakdownPhotoAnnotation? annotationFor(int index) {
    for (final annotation in widget.draft.photoAnnotations) {
      if (annotation.photoIndex == index) {
        return annotation;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return RaDriverScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: RaDriverAppBarTitle(
          'Review Request',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  const _RaReviewProgress(),

                  const SizedBox(height: 16),

                  const _RaReviewHero(),

                  const SizedBox(height: 26),

                  const _RaReviewHeading(
                    title: 'Provider preference',
                    subtitle: 'This controls who receives the request first.',
                  ),

                  const SizedBox(height: 11),

                  _RaReviewProviderCard(
                    specificProvider: specificProvider,
                    providerName: widget.draft.provider,
                  ),

                  const SizedBox(height: 26),

                  const _RaReviewHeading(
                    title: 'Request summary',
                    subtitle:
                        'Check the vehicle, problem and roadside location.',
                  ),

                  const SizedBox(height: 11),

                  _RaReviewSurface(
                    child: Column(
                      children: [
                        _RaReviewRow(
                          icon: Icons.car_repair_outlined,
                          label: 'Assistance',
                          value: widget.draft.issue,
                        ),

                        const _RaReviewDivider(),

                        _RaReviewRow(
                          icon: Icons.priority_high_rounded,
                          label: 'Priority',
                          value: requestPriorityLabel(widget.draft.priority),
                        ),

                        const _RaReviewDivider(),

                        _RaReviewRow(
                          icon: Icons.directions_car_outlined,
                          label: 'Vehicle',
                          value:
                              '${widget.draft.modelYear} • ${widget.draft.vehicleType}',
                        ),

                        const _RaReviewDivider(),

                        _RaReviewRow(
                          icon: Icons.pin_outlined,
                          label: 'Registration',
                          value: widget.draft.registration.toUpperCase(),
                        ),

                        const _RaReviewDivider(),

                        _RaReviewRow(
                          icon: Icons.location_on_outlined,
                          label: 'Breakdown location',
                          value: widget.draft.location,
                        ),

                        if (widget.draft.landmark.isNotEmpty) ...[
                          const _RaReviewDivider(),

                          _RaReviewRow(
                            icon: Icons.signpost_outlined,
                            label: 'Landmark',
                            value: widget.draft.landmark,
                          ),
                        ],

                        if (widget.draft.description.trim().isNotEmpty) ...[
                          const _RaReviewDivider(),

                          _RaReviewRow(
                            icon: Icons.description_outlined,
                            label: 'Symptoms',
                            value: widget.draft.description,
                          ),
                        ],

                        const _RaReviewDivider(),

                        _RaReviewRow(
                          icon: Icons.settings_outlined,
                          label: 'Parts preference',
                          value: partsPreferenceLabel(
                            widget.draft.partsPreference,
                          ),
                        ),

                        if (widget.draft.notes.trim().isNotEmpty) ...[
                          const _RaReviewDivider(),

                          _RaReviewRow(
                            icon: Icons.sticky_note_2_outlined,
                            label: 'Additional notes',
                            value: widget.draft.notes,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  const _RaReviewHeading(
                    title: 'Photo evidence',
                    subtitle:
                        'Photos are shared with providers reviewing this request.',
                  ),

                  const SizedBox(height: 11),

                  _buildEvidence(context),

                  const SizedBox(height: 26),

                  const _RaReviewHeading(
                    title: 'Pricing',
                    subtitle:
                        'No payment is confirmed when the request is submitted.',
                  ),

                  const SizedBox(height: 11),

                  _RaReviewSurface(
                    child: Column(
                      children: [
                        const _RaPricingPoint(
                          icon: Icons.request_quote_outlined,
                          title: 'Providers send offers',
                          message:
                              'Service, travel and any other stated charges are shown before approval.',
                        ),

                        const SizedBox(height: 11),

                        const _RaPricingPoint(
                          icon: Icons.compare_arrows_rounded,
                          title: 'You choose before assignment',
                          message:
                              'Compare available offers or approve the selected provider’s offer.',
                        ),

                        const SizedBox(height: 11),

                        const _RaPricingPoint(
                          icon: Icons.verified_user_outlined,
                          title: 'Changes need approval',
                          message:
                              'If repair work changes after inspection, a revised quote must be approved first.',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: raGold.withValues(alpha: .075),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.health_and_safety_outlined,
                          color: raGold,
                          size: 19,
                        ),

                        const SizedBox(width: 9),

                        Expanded(
                          child: Text(
                            'If there is immediate danger, contact emergency services before waiting for a roadside provider.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              height: 1.45,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _RaReviewBottomBar(
              ready: readyToSubmit,
              submitting: submitting,
              onSubmit: () {
                unawaited(submitRequest());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidence(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final photos = widget.draft.vehiclePhotoUrls;

    if (photos.isEmpty) {
      return _RaReviewSurface(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.photo_outlined, color: colors.onSurfaceVariant),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No photos added',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    'Photo evidence is optional.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _RaReviewSurface(
      child: SizedBox(
        height: 112,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: photos.length,
          separatorBuilder: (context, index) {
            return const SizedBox(width: 8);
          },
          itemBuilder: (context, index) {
            final annotation = annotationFor(index);

            Widget image;

            try {
              image = Image.memory(
                base64Decode(photos[index]),
                width: 112,
                height: 112,
                fit: BoxFit.cover,
              );
            } on FormatException {
              image = Container(
                width: 112,
                height: 112,
                alignment: Alignment.center,
                color: colors.surfaceContainerHighest,
                child: const Icon(Icons.broken_image_outlined),
              );
            }

            return SizedBox(
              width: 112,
              height: 112,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: image,
                    ),
                  ),

                  if (annotation != null)
                    Positioned(
                      left: (annotation.markerX * 92)
                          .clamp(0.0, 85.0)
                          .toDouble(),
                      top: (annotation.markerY * 87)
                          .clamp(0.0, 78.0)
                          .toDouble(),
                      child: Icon(
                        Icons.location_on_rounded,
                        color: colors.error,
                        size: 24,
                        shadows: const [
                          Shadow(color: Colors.white, blurRadius: 4),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RaReviewProgress extends StatelessWidget {
  const _RaReviewProgress();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'STEP 4 OF 4',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  letterSpacing: .8,
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            const Spacer(),

            Text(
              'Review',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),

        const SizedBox(height: 7),

        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: 1,
            minHeight: 5,
            backgroundColor: colors.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _RaReviewHero extends StatelessWidget {
  const _RaReviewHero();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF0B477D), Color(0xFF08645D)]
              : const [Color(0xFF075BA8), Color(0xFF078C7E)],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Container(
            width: 51,
            height: 51,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: Colors.white,
              size: 25,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to request help?',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'Check your vehicle, location and assistance details before sending the request.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: .80),
                    fontSize: 13,
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

class _RaReviewHeading extends StatelessWidget {
  const _RaReviewHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -.35,
            color: colors.onSurface,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            height: 1.4,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RaReviewProviderCard extends StatelessWidget {
  const _RaReviewProviderCard({
    required this.specificProvider,
    required this.providerName,
  });

  final bool specificProvider;
  final String providerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final title = specificProvider ? providerName : 'Receive provider offers';

    return _RaReviewSurface(
      child: Row(
        children: [
          specificProvider
              ? ProfileInitials(name: title, radius: 25)
              : Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.compare_arrows_rounded,
                    color: colors.primary,
                  ),
                ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  specificProvider
                      ? 'The request will be directed to this provider first.'
                      : 'Suitable providers can review the request and send offers for comparison.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.4,
                    color: colors.onSurfaceVariant,
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

class _RaReviewSurface extends StatelessWidget {
  const _RaReviewSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF0D2237)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      child: child,
    );
  }
}

class _RaReviewRow extends StatelessWidget {
  const _RaReviewRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colors.primary),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
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

class _RaReviewDivider extends StatelessWidget {
  const _RaReviewDivider();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Divider(
      height: 1,
      indent: 28,
      color: colors.outlineVariant.withValues(alpha: .34),
    );
  }
}

class _RaPricingPoint extends StatelessWidget {
  const _RaPricingPoint({
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colors.primary, size: 18),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  height: 1.4,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RaReviewSafetyTile extends StatelessWidget {
  const _RaReviewSafetyTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final bool value;
  final bool danger;

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final tone = danger ? colors.error : colors.primary;

    return Material(
      color: value
          ? tone.withValues(alpha: .07)
          : colors.surfaceContainerHighest.withValues(alpha: .35),
      borderRadius: BorderRadius.circular(15),
      child: CheckboxListTile(
        value: value,
        onChanged: (newValue) {
          onChanged(newValue ?? false);
        },
        secondary: Icon(icon, color: tone),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        controlAffinity: ListTileControlAffinity.trailing,
        contentPadding: const EdgeInsets.symmetric(horizontal: 11),
      ),
    );
  }
}

class _RaReviewBottomBar extends StatelessWidget {
  const _RaReviewBottomBar({
    required this.ready,
    required this.submitting,
    required this.onSubmit,
  });

  final bool ready;
  final bool submitting;

  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: .45)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: FilledButton.icon(
          onPressed: ready && !submitting ? onSubmit : null,
          icon: submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_rounded),
          label: Text(
            submitting
                ? 'Sending Request…'
                : ready
                ? 'Request Roadside Assistance'
                : 'Complete Request Details',
          ),
        ),
      ),
    );
  }
}
