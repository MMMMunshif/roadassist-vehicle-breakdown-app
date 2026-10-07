part of '../../screens.dart';

class RealtimeDriverRequestDetailsScreen extends StatelessWidget {
  const RealtimeDriverRequestDetailsScreen({
    super.key,
    required this.requestId,
    required this.data,
  });

  final String requestId;
  final Map<String, dynamic> data;

  String get status => data['status'] as String? ?? 'searching';

  String get provider =>
      data['providerName'] as String? ?? 'Not assigned';

  String get providerPhone =>
      data['providerPhone'] as String? ?? '';

  bool get providerAssigned =>
      (data['providerId'] as String? ?? '').trim().isNotEmpty;

  int money(String key) => (data[key] as num?)?.toInt() ?? 0;

  String formatMoney(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer();

    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        buffer.write(',');
      }

      buffer.write(digits[index]);
    }

    return 'Rs. ${value < 0 ? '-' : ''}${buffer.toString()}';
  }

  String statusLabel() {
    return switch (status) {
      'searching' => 'Searching',
      'accepted' => 'Accepted',
      'en_route' => 'En route',
      'arrived' => 'Provider arrived',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => status.replaceAll('_', ' '),
    };
  }

  String statusDescription() {
    return switch (status) {
      'searching' =>
        'RoadAssist is looking for an available service provider.',
      'accepted' =>
        'A provider has accepted your roadside assistance request.',
      'en_route' =>
        'Your assigned provider is travelling to your location.',
      'arrived' =>
        data['completionState'] == 'pending'
            ? 'The provider has completed work and is waiting for your review.'
            : 'Your provider has reached your breakdown location.',
      'completed' =>
        'Your roadside assistance request has been completed.',
      'cancelled' =>
        'This roadside assistance request is no longer active.',
      _ => 'View the latest information for this assistance request.',
    };
  }

  RaTone statusTone() {
    return switch (status) {
      'completed' => RaTone.success,
      'cancelled' => RaTone.danger,
      'arrived' => RaTone.success,
      _ => RaTone.info,
    };
  }

  Color statusColor(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return switch (status) {
      'completed' => raSuccess,
      'cancelled' => colors.error,
      'arrived' => raSuccess,
      'en_route' => const Color(0xFF167DE4),
      _ => colors.primary,
    };
  }

  IconData statusIcon() {
    return switch (status) {
      'searching' => Icons.person_search_rounded,
      'accepted' => Icons.handshake_outlined,
      'en_route' => Icons.navigation_rounded,
      'arrived' => Icons.location_on_rounded,
      'completed' => Icons.task_alt_rounded,
      'cancelled' => Icons.close_rounded,
      _ => Icons.car_repair_outlined,
    };
  }

  int timelineIndex() {
    return switch (status) {
      'accepted' => 0,
      'en_route' => 1,
      'arrived' => 2,
      'completed' => 3,
      _ => 0,
    };
  }

  void showReceipt(BuildContext context) {
    push(
      context,
      InvoiceScreen(requestId: requestId),
    );
  }

  Future<void> rateService(BuildContext context) async {
    var selectedRating =
        (data['driverRating'] as num?)?.toInt() ?? 0;

    final rating = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final colors = theme.colorScheme;
            final dark = theme.brightness == Brightness.dark;

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: dark
                    ? const Color(0xFF0D1D2B)
                    : colors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.onSurfaceVariant.withValues(
                        alpha: .24,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),

                  const SizedBox(height: 23),

                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: raGold.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: raGold,
                      size: 31,
                    ),
                  ),

                  const SizedBox(height: 15),

                  Text(
                    'Rate your service',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.45,
                      color: colors.onSurface,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'How was your RoadAssist experience?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 19),

                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (index) => IconButton(
                          onPressed: () {
                            setSheetState(() {
                              selectedRating = index + 1;
                            });
                          },
                          icon: Icon(
                            index < selectedRating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: raGold,
                            size: 35,
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (selectedRating > 0) ...[
                    const SizedBox(height: 5),
                    Text(
                      '$selectedRating / 5',
                      style: GoogleFonts.plusJakartaSans(
                        color: raGold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: selectedRating == 0
                          ? null
                          : () {
                              Navigator.pop(
                                sheetContext,
                                selectedRating,
                              );
                            },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Submit Rating'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (rating == null || !context.mounted) return;

    try {
      await RequestService().submitDriverRating(
        requestId,
        rating,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Thank you for your $rating-star rating.',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to save rating. Try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final latitude =
        (data['latitude'] as num?)?.toDouble();

    final longitude =
        (data['longitude'] as num?)?.toDouble();

    final hasCoordinates =
        latitude != null && longitude != null;

    final serviceFee = money('serviceFee');
    final travelFee = money('dispatchFee');
    final extraFee = money('extraFee');
    final quotedTotal = money('estimatedCost');

    final finalTotal = data['finalCost'] == null
        ? quotedTotal
        : money('finalCost');

    final location =
        data['locationLabel'] as String? ??
        data['location'] as String? ??
        'Location not recorded';

    final vehicle =
        data['modelYear'] as String? ??
        data['vehicleType'] as String? ??
        'Not provided';

    final registration =
        data['registration'] as String? ?? 'Not provided';

    final issue = requestIssueLabel(data);

    final description =
        data['description'] as String? ?? '';

    final quoteNotes =
        data['quoteNotes'] as String? ?? '';

    final providerDistance =
        (data['providerDistanceKm'] as num?)?.toDouble();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Request Details',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          18,
          9,
          18,
          32,
        ),
        children: [
          _RaDriverRequestStatusHero(
            label: statusLabel(),
            description: statusDescription(),
            icon: statusIcon(),
            tone: statusColor(context),
          ),

          const SizedBox(height: 14),

          if (hasCoordinates)
            Container(
              height: 210,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: colors.outlineVariant.withValues(
                    alpha: .50,
                  ),
                ),
              ),
              child: MapMock(
                position: LatLng(
                  latitude,
                  longitude,
                ),
              ),
            )
          else
            _RaDriverRequestNoMap(
              location: location,
            ),

          if (providerAssigned) ...[
            const SizedBox(height: 14),

            _RaDriverProviderCard(
              name: provider,
              phone: providerPhone,
              requestId: requestId,
            ),
          ],

          const SizedBox(height: 27),

          const _RaDriverDetailsSectionHeading(
            title: 'Request information',
            subtitle:
                'Vehicle, assistance and breakdown details',
          ),

          const SizedBox(height: 11),

          _RaDriverDetailsCard(
            children: [
              _RaDriverDetailRow(
                icon: Icons.tag_rounded,
                label: 'Request ID',
                value: requestId,
              ),
              _RaDriverDetailRow(
                icon: Icons.car_repair_outlined,
                label: 'Assistance',
                value: issue,
              ),
              _RaDriverDetailRow(
                icon: Icons.directions_car_outlined,
                label: 'Vehicle',
                value: vehicle,
              ),
              _RaDriverDetailRow(
                icon: Icons.pin_outlined,
                label: 'Registration',
                value: registration,
              ),
              _RaDriverDetailRow(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: location,
              ),
              if (description.trim().isNotEmpty)
                _RaDriverDetailRow(
                  icon: Icons.description_outlined,
                  label: 'Description',
                  value: description,
                ),
            ],
          ),

          if (providerAssigned) ...[
            const SizedBox(height: 27),

            const _RaDriverDetailsSectionHeading(
              title: 'Price summary',
              subtitle:
                  'Charges recorded for the selected service',
            ),

            const SizedBox(height: 11),

            _RaDriverDetailsCard(
              children: [
                _RaDriverDetailRow(
                  icon: Icons.build_outlined,
                  label: 'Service / labour',
                  value: formatMoney(serviceFee),
                ),
                _RaDriverDetailRow(
                  icon: Icons.route_outlined,
                  label: 'Travel',
                  value: formatMoney(travelFee),
                ),
                _RaDriverDetailRow(
                  icon: Icons.add_card_outlined,
                  label: 'Other charges',
                  value: formatMoney(extraFee),
                ),
                if (providerDistance != null)
                  _RaDriverDetailRow(
                    icon: Icons.near_me_outlined,
                    label: 'Provider distance',
                    value:
                        '${providerDistance.toStringAsFixed(1)} km',
                  ),
                if (quoteNotes.trim().isNotEmpty)
                  _RaDriverDetailRow(
                    icon: Icons.notes_outlined,
                    label: 'Quote notes',
                    value: quoteNotes,
                  ),
                _RaDriverDetailRow(
                  icon: Icons.payments_outlined,
                  label: data['finalCost'] == null
                      ? 'Quoted total'
                      : 'Final total',
                  value: formatMoney(finalTotal),
                  strong: true,
                ),
              ],
            ),
          ],

          if (const [
            'accepted',
            'en_route',
            'arrived',
            'completed',
          ].contains(status)) ...[
            const SizedBox(height: 27),

            const _RaDriverDetailsSectionHeading(
              title: 'Service progress',
              subtitle:
                  'Follow the current roadside assistance stage',
            ),

            const SizedBox(height: 11),

            _RaDriverDetailsCard(
              padding: const EdgeInsets.all(17),
              children: [
                StatusTimeline(
                  statuses: const [
                    'Accepted',
                    'En Route',
                    'Arrived',
                    'Completed',
                  ],
                  current: timelineIndex(),
                ),
              ],
            ),
          ],

          if (status == 'completed') ...[
            const SizedBox(height: 27),

            const _RaDriverDetailsSectionHeading(
              title: 'Service warranty',
              subtitle:
                  'Coverage recorded with the approved service',
            ),

            const SizedBox(height: 11),

            _RaDriverDetailsCard(
              padding: const EdgeInsets.all(17),
              children: [
                ServiceWarranty(
                  requestId: requestId,
                  job: data,
                ),
              ],
            ),

            const SizedBox(height: 22),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showReceipt(context);
                    },
                    icon: const Icon(
                      Icons.receipt_long_outlined,
                    ),
                    label: const Text('Receipt'),
                  ),
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      rateService(context);
                    },
                    icon: const Icon(
                      Icons.star_outline_rounded,
                    ),
                    label: Text(
                      data['driverRating'] == null
                          ? 'Rate'
                          : 'Update Rating',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: colors.error,
                ),
                onPressed: () {
                  push(
                    context,
                    DisputeScreen(
                      requestId: requestId,
                    ),
                  );
                },
                icon: const Icon(
                  Icons.report_problem_outlined,
                ),
                label: const Text(
                  'Report a Problem',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RaDriverRequestStatusHero extends StatelessWidget {
  const _RaDriverRequestStatusHero({
    required this.label,
    required this.description,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String description;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context).brightness == Brightness.dark;

    final end = tone == raSuccess
        ? const Color(0xFF087469)
        : tone == raDanger
            ? const Color(0xFF9F2A24)
            : dark
                ? const Color(0xFF075C79)
                : const Color(0xFF087C73);

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tone, end],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: tone.withValues(alpha: .18),
            blurRadius: 24,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 27,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.4,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  description,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: .80),
                    fontSize: 10.5,
                    height: 1.45,
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

class _RaDriverProviderCard extends StatelessWidget {
  const _RaDriverProviderCard({
    required this.name,
    required this.phone,
    required this.requestId,
  });

  final String name;
  final String phone;
  final String requestId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFF0D1D2B)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: .48),
        ),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ProfileInitials(
                name: name,
                radius: 25,
              ),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: raSuccess,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: dark
                          ? const Color(0xFF0D1D2B)
                          : Colors.white,
                      width: 2.5,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Assigned service provider',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            tooltip: 'Message',
            onPressed: () {
              push(
                context,
                ChatScreen(
                  requestId: requestId,
                  peerName: name,
                  peerPhone: phone,
                ),
              );
            },
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
            ),
          ),

          IconButton(
            tooltip: 'Call',
            onPressed: phone.trim().isEmpty
                ? null
                : () {
                    showCallPrompt(
                      context,
                      name: name,
                      number: phone,
                    );
                  },
            icon: const Icon(
              Icons.call_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaDriverDetailsSectionHeading extends StatelessWidget {
  const _RaDriverDetailsSectionHeading({
    required this.title,
    required this.subtitle,
  });

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
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -.35,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RaDriverDetailsCard extends StatelessWidget {
  const _RaDriverDetailsCard({
    required this.children,
    this.padding = const EdgeInsets.symmetric(
      horizontal: 15,
    ),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFF0D1D2B)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: .48),
        ),
      ),
      child: Column(
        children: [
          for (var index = 0;
              index < children.length;
              index++) ...[
            children[index],
            if (index != children.length - 1)
              Divider(
                height: 1,
                color: colors.outlineVariant.withValues(
                  alpha: .38,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RaDriverDetailRow extends StatelessWidget {
  const _RaDriverDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.strong = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 17,
              color: colors.primary,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    color: colors.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: strong ? 12.5 : 11,
                    height: 1.4,
                    fontWeight:
                        strong ? FontWeight.w800 : FontWeight.w600,
                    color: strong
                        ? colors.primary
                        : colors.onSurface,
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

class _RaDriverRequestNoMap extends StatelessWidget {
  const _RaDriverRequestNoMap({
    required this.location,
  });

  final String location;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: .48),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.location_off_outlined,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              location,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                height: 1.4,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}