part of '../../screens.dart';

class RealtimeDriverRequestDetailsScreen extends StatelessWidget {
  const RealtimeDriverRequestDetailsScreen({
    super.key,
    required this.requestId,
    required this.data,
  });

  final String requestId;
  final Map<String, dynamic> data;

  String formatMoney(num value) {
    final amount = value.toInt().abs().toString();

    final buffer = StringBuffer();

    for (var index = 0; index < amount.length; index++) {
      if (index > 0 && (amount.length - index) % 3 == 0) {
        buffer.write(',');
      }

      buffer.write(amount[index]);
    }

    return 'Rs. ${value < 0 ? '-' : ''}${buffer.toString()}';
  }

  String statusLabel(String status) {
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

  RaTone statusTone(String status) {
    return switch (status) {
      'completed' => RaTone.success,
      'cancelled' => RaTone.danger,
      'searching' => RaTone.warning,
      'arrived' => RaTone.success,
      _ => RaTone.info,
    };
  }

  int timelineIndex(String status) {
    return switch (status) {
      'accepted' => 0,
      'en_route' => 1,
      'arrived' => 2,
      'completed' => 3,
      _ => 0,
    };
  }

  Future<void> rateService(
    BuildContext context,
    Map<String, dynamic> job,
  ) async {
    var selectedRating = (job['driverRating'] as num?)?.toInt() ?? 0;

    final rating = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final colors = Theme.of(context).colorScheme;

            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: raGold.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: raGold,
                      size: 29,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Rate your service',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'How was your roadside assistance experience?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 15),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
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
                          size: 34,
                        ),
                      );
                    }),
                  ),

                  if (selectedRating > 0) ...[
                    Text(
                      '$selectedRating of 5',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: raGold,
                      ),
                    ),
                  ],

                  const SizedBox(height: 15),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: selectedRating == 0
                          ? null
                          : () {
                              Navigator.pop(sheetContext, selectedRating);
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

    if (rating == null || !context.mounted) {
      return;
    }

    try {
      await RequestService().submitDriverRating(requestId, rating);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thank you for your $rating-star rating.')),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save rating. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RaDriverScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: RaDriverAppBarTitle(
          'Request Details',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('requests')
            .doc(requestId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.all(18),
              child: EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Unable to load request',
                message: 'Check your connection and try again.',
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final current = snapshot.data!.data() ?? data;

          if (!snapshot.data!.exists && current.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(18),
              child: EmptyState(
                icon: Icons.search_off_outlined,
                title: 'Request not found',
                message: 'This assistance request is no longer available.',
              ),
            );
          }

          return _RaRealtimeRequestBody(
            requestId: requestId,
            data: current,
            formatMoney: formatMoney,
            statusLabel: statusLabel,
            statusTone: statusTone,
            timelineIndex: timelineIndex,
            onRate: () {
              rateService(context, current);
            },
          );
        },
      ),
    );
  }
}

class _RaRealtimeRequestBody extends StatelessWidget {
  const _RaRealtimeRequestBody({
    required this.requestId,
    required this.data,
    required this.formatMoney,
    required this.statusLabel,
    required this.statusTone,
    required this.timelineIndex,
    required this.onRate,
  });

  final String requestId;
  final Map<String, dynamic> data;

  final String Function(num) formatMoney;

  final String Function(String) statusLabel;

  final RaTone Function(String) statusTone;

  final int Function(String) timelineIndex;

  final VoidCallback onRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final status = data['status'] as String? ?? 'searching';

    final provider = data['providerName']?.toString().trim() ?? '';

    final providerId = data['providerId']?.toString().trim() ?? '';

    final providerPhone = data['providerPhone']?.toString().trim() ?? '';

    final providerAssigned = providerId.isNotEmpty;

    final latitude = (data['latitude'] as num?)?.toDouble();

    final longitude = (data['longitude'] as num?)?.toDouble();

    final location =
        data['locationLabel']?.toString().trim() ??
        data['location']?.toString().trim() ??
        '';

    final registration = data['registration']?.toString().trim() ?? '';

    final vehicleParts = [
      data['vehicleType']?.toString().trim(),
      data['modelYear']?.toString().trim(),
    ].whereType<String>().where((value) => value.isNotEmpty).toList();

    final vehicle = vehicleParts.isEmpty
        ? 'Not recorded'
        : vehicleParts.join(' • ');

    final description = data['description']?.toString().trim() ?? '';

    final quoteNotes = data['quoteNotes']?.toString().trim() ?? '';

    final cancellationReason =
        data['cancellationReason']?.toString().trim() ?? '';

    final serviceFee = data['serviceFee'] as num?;

    final dispatchFee = data['dispatchFee'] as num?;

    final extraFee = data['extraFee'] as num?;

    final estimatedCost = data['estimatedCost'] as num?;

    final finalCost = data['finalCost'] as num?;

    final total = finalCost ?? estimatedCost;

    final providerDistance = (data['providerDistanceKm'] as num?)?.toDouble();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
      children: [
        _RaRealtimeHero(
          status: status,
          label: statusLabel(status),
          tone: statusTone(status),
        ),

        if (status == 'cancelled' && cancellationReason.isNotEmpty) ...[
          const SizedBox(height: 12),

          _RaRealtimeNotice(
            icon: Icons.info_outline_rounded,
            title: 'Cancellation information',
            message: cancellationReason,
            tone: colors.error,
          ),
        ],

        if (latitude != null && longitude != null) ...[
          const SizedBox(height: 15),

          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 210,
              child: MapMock(position: LatLng(latitude, longitude)),
            ),
          ),
        ],

        if (providerAssigned) ...[
          const SizedBox(height: 15),

          _RaRealtimeProviderCard(
            name: provider.isEmpty ? 'Service Provider' : provider,
            phone: providerPhone,
            onCall: providerPhone.isEmpty
                ? null
                : () {
                    showCallPrompt(
                      context,
                      name: provider.isEmpty ? 'Service Provider' : provider,
                      number: providerPhone,
                    );
                  },
            onChat: () {
              push(
                context,
                ChatScreen(
                  requestId: requestId,
                  peerName: provider.isEmpty ? 'Service Provider' : provider,
                  peerPhone: providerPhone,
                ),
              );
            },
          ),
        ],

        const SizedBox(height: 23),

        const _RaRealtimeHeading(
          title: 'Request information',
          subtitle: 'Details recorded for this roadside assistance request.',
        ),

        const SizedBox(height: 10),

        _RaRealtimeSurface(
          child: Column(
            children: [
              _RaRealtimeRow(
                label: 'Assistance',
                value: requestIssueLabel(data),
              ),
              const Divider(height: 1),
              _RaRealtimeRow(label: 'Vehicle', value: vehicle),
              const Divider(height: 1),
              _RaRealtimeRow(
                label: 'Registration',
                value: registration.isEmpty ? 'Not recorded' : registration,
              ),
              const Divider(height: 1),
              _RaRealtimeRow(
                label: 'Location',
                value: location.isEmpty ? 'Not recorded' : location,
              ),
              if (description.isNotEmpty) ...[
                const Divider(height: 1),
                _RaRealtimeRow(label: 'Description', value: description),
              ],
            ],
          ),
        ),

        if (providerAssigned &&
            (serviceFee != null ||
                dispatchFee != null ||
                extraFee != null ||
                total != null ||
                quoteNotes.isNotEmpty ||
                providerDistance != null)) ...[
          const SizedBox(height: 23),

          const _RaRealtimeHeading(
            title: 'Price summary',
            subtitle: 'Only amounts recorded against this request are shown.',
          ),

          const SizedBox(height: 10),

          _RaRealtimeSurface(
            child: Column(
              children: [
                if (serviceFee != null)
                  _RaRealtimeRow(
                    label: 'Service / labour',
                    value: formatMoney(serviceFee),
                  ),

                if (serviceFee != null && dispatchFee != null)
                  const Divider(height: 1),

                if (dispatchFee != null)
                  _RaRealtimeRow(
                    label: 'Travel / dispatch',
                    value: formatMoney(dispatchFee),
                  ),

                if ((serviceFee != null || dispatchFee != null) &&
                    extraFee != null)
                  const Divider(height: 1),

                if (extraFee != null)
                  _RaRealtimeRow(
                    label: 'Other charges',
                    value: formatMoney(extraFee),
                  ),

                if (providerDistance != null) ...[
                  const Divider(height: 1),
                  _RaRealtimeRow(
                    label: 'Recorded provider distance',
                    value: '${providerDistance.toStringAsFixed(1)} km',
                  ),
                ],

                if (quoteNotes.isNotEmpty) ...[
                  const Divider(height: 1),
                  _RaRealtimeRow(label: 'Quote notes', value: quoteNotes),
                ],

                if (total != null) ...[
                  const Divider(height: 1),
                  _RaRealtimeRow(
                    label: finalCost != null ? 'Final total' : 'Quoted total',
                    value: formatMoney(total),
                    strong: true,
                  ),
                ],
              ],
            ),
          ),
        ],

        if (const [
          'accepted',
          'en_route',
          'arrived',
          'completed',
        ].contains(status)) ...[
          const SizedBox(height: 23),

          const _RaRealtimeHeading(
            title: 'Request progress',
            subtitle: 'Current roadside assistance stage.',
          ),

          const SizedBox(height: 10),

          _RaRealtimeSurface(
            child: StatusTimeline(
              statuses: const ['Accepted', 'En Route', 'Arrived', 'Completed'],
              current: timelineIndex(status),
            ),
          ),
        ],

        if (status == 'completed') ...[
          const SizedBox(height: 23),

          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 390;

              final receipt = OutlinedButton.icon(
                onPressed: () {
                  push(context, InvoiceScreen(requestId: requestId));
                },
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('View / Download Invoice'),
              );

              final rating = FilledButton.icon(
                onPressed: data['driverRating'] == null ? onRate : null,
                icon: const Icon(Icons.star_outline_rounded),
                label: Text(
                  data['driverRating'] == null
                      ? 'Rate Service'
                      : 'Rated ${data['driverRating']}/5',
                ),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [receipt, const SizedBox(height: 8), rating],
                );
              }

              return Row(
                children: [
                  Expanded(child: receipt),
                  const SizedBox(width: 8),
                  Expanded(child: rating),
                ],
              );
            },
          ),

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: colors.error),
              onPressed: () {
                push(context, DisputeScreen(requestId: requestId));
              },
              icon: const Icon(Icons.report_problem_outlined),
              label: const Text('Report a Problem'),
            ),
          ),
        ],
      ],
    );
  }
}

class _RaRealtimeHero extends StatelessWidget {
  const _RaRealtimeHero({
    required this.status,
    required this.label,
    required this.tone,
  });

  final String status;
  final String label;
  final RaTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final completed = status == 'completed';

    final cancelled = status == 'cancelled';

    final start = cancelled
        ? colors.error
        : completed
        ? raSuccess
        : colors.primary;

    final end = cancelled
        ? const Color(0xFF9C2922)
        : completed
        ? const Color(0xFF087064)
        : const Color(0xFF087E75);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, end],
        ),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              completed
                  ? Icons.task_alt_rounded
                  : cancelled
                  ? Icons.close_rounded
                  : Icons.car_repair_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
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
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  completed
                      ? 'Your roadside assistance has been completed.'
                      : cancelled
                      ? 'This roadside assistance request was cancelled.'
                      : 'Latest information for your roadside assistance request.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 12,
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

class _RaRealtimeProviderCard extends StatelessWidget {
  const _RaRealtimeProviderCard({
    required this.name,
    required this.phone,
    required this.onCall,
    required this.onChat,
  });

  final String name;
  final String phone;
  final VoidCallback? onCall;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF0D2237)
            : colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      child: Row(
        children: [
          ProfileInitials(name: name, radius: 23),
          const SizedBox(width: 10),
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
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Assigned service provider',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Call',
            onPressed: onCall,
            icon: const Icon(Icons.call_outlined),
          ),
          const SizedBox(width: 4),
          IconButton.filledTonal(
            tooltip: 'Message',
            onPressed: onChat,
            icon: const Icon(Icons.chat_bubble_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _RaRealtimeHeading extends StatelessWidget {
  const _RaRealtimeHeading({required this.title, required this.subtitle});

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
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            height: 1.4,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RaRealtimeSurface extends StatelessWidget {
  const _RaRealtimeSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF0D2237)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .45),
        ),
      ),
      child: child,
    );
  }
}

class _RaRealtimeRow extends StatelessWidget {
  const _RaRealtimeRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.plusJakartaSans(
                fontSize: strong ? 10 : 8.8,
                height: 1.4,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
                color: strong ? colors.primary : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaRealtimeNotice extends StatelessWidget {
  const _RaRealtimeNotice({
    required this.icon,
    required this.title,
    required this.message,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: tone.withValues(alpha: .17)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tone),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
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
      ),
    );
  }
}
