part of '../../screens.dart';

class ProviderRequestDetailsScreen extends StatelessWidget {
  const ProviderRequestDetailsScreen({
    super.key,
    required this.requestId,
    required this.data,
  });

  final String requestId;
  final Map<String, dynamic> data;

  String _statusLabel(String status) {
    return switch (status) {
      'searching' => 'Searching',
      'accepted' => 'Accepted',
      'en_route' => 'En route',
      'arrived' => 'Arrived',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => status.replaceAll('_', ' '),
    };
  }

  RaTone _statusTone(String status) {
    return switch (status) {
      'completed' => RaTone.success,
      'cancelled' => RaTone.danger,
      'arrived' => RaTone.success,
      'accepted' || 'en_route' => RaTone.info,
      _ => RaTone.neutral,
    };
  }

  String _money(int amount) {
    final value = amount.abs().toString();
    final output = StringBuffer();

    for (var index = 0; index < value.length; index++) {
      if (index > 0 && (value.length - index) % 3 == 0) {
        output.write(',');
      }

      output.write(value[index]);
    }

    return 'Rs. ${amount < 0 ? '-' : ''}${output.toString()}';
  }

  String _dateTime(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Time unavailable';
    }

    final value = timestamp.toDate().toLocal();

    final day = value.day.toString().padLeft(2, '0');

    final month = value.month.toString().padLeft(2, '0');

    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;

    final minute = value.minute.toString().padLeft(2, '0');

    final period = value.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/${value.year} • $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: signedIn ? RequestService().watchRequest(requestId) : null,
      builder: (context, snapshot) {
        final liveData = snapshot.data?.data();

        final requestData = liveData == null
            ? data
            : <String, dynamic>{...data, ...liveData};

        return _ProviderRequestDetailsContent(
          requestId: requestId,
          data: requestData,
          statusLabel: _statusLabel,
          statusTone: _statusTone,
          money: _money,
          dateTime: _dateTime,
        );
      },
    );
  }
}

class _ProviderRequestDetailsContent extends StatelessWidget {
  const _ProviderRequestDetailsContent({
    required this.requestId,
    required this.data,
    required this.statusLabel,
    required this.statusTone,
    required this.money,
    required this.dateTime,
  });

  final String requestId;
  final Map<String, dynamic> data;

  final String Function(String) statusLabel;
  final RaTone Function(String) statusTone;
  final String Function(int) money;
  final String Function(Timestamp?) dateTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final rawStatus = data['status'] as String? ?? 'unknown';

    final driver = data['driverName'] as String? ?? 'Driver';

    final phone = data['driverPhone'] as String? ?? '';

    final latitude = (data['latitude'] as num?)?.toDouble();

    final longitude = (data['longitude'] as num?)?.toDouble();

    final hasCoordinates = latitude != null && longitude != null;

    final vehicle = [
      data['vehicleType'] as String? ?? '',
      data['modelYear'] as String? ?? '',
      data['registration'] as String? ?? '',
    ].where((value) => value.trim().isNotEmpty).join(' • ');

    final description = data['description'] as String? ?? '';

    final notes = data['notes'] as String? ?? '';

    final location =
        data['locationLabel'] as String? ??
        data['location'] as String? ??
        'Location unavailable';

    final landmark = data['landmark'] as String? ?? '';

    final priority = data['priority'] as String? ?? 'normal';

    final serviceFee = (data['serviceFee'] as num?)?.toInt() ?? 0;

    final travelFee =
        (data['dispatchFee'] as num?)?.toInt() ??
        (data['travelFee'] as num?)?.toInt() ??
        0;

    final extraFee = (data['extraFee'] as num?)?.toInt() ?? 0;

    final estimatedCost = (data['estimatedCost'] as num?)?.toInt() ?? 0;

    final finalCost = (data['finalCost'] as num?)?.toInt();

    final vehiclePhotos =
        (data['vehiclePhotoUrls'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList();

    final active = const [
      'accepted',
      'en_route',
      'arrived',
    ].contains(rawStatus);

    final searching = rawStatus == 'searching';

    return RaProviderScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const BrandMark(size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Request Details',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.45,
                ),
              ),
            ),
          ],
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: _WelcomeThemeToggle(),
          ),
          if (rawStatus == 'completed')
            IconButton(
              tooltip: 'Invoice',
              onPressed: () {
                push(context, InvoiceScreen(requestId: requestId));
              },
              icon: const Icon(Icons.receipt_long_outlined),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          _RaProviderCaseHero(
            requestId: requestId,
            status: statusLabel(rawStatus),
            tone: statusTone(rawStatus),
            issue: requestIssueLabel(data),
            date: dateTime(data['createdAt'] as Timestamp?),
            priority: priority,
          ),

          const SizedBox(height: 22),

          const _RaProviderDetailHeading(
            title: 'Driver',
            subtitle: 'Contact and customer information for this request.',
          ),

          const SizedBox(height: 10),

          _RaProviderDriverCard(
            name: driver,
            phone: phone,
            requestId: requestId,
          ),

          const SizedBox(height: 22),

          const _RaProviderDetailHeading(
            title: 'Breakdown details',
            subtitle:
                'Review the vehicle, reported problem and roadside notes.',
          ),

          const SizedBox(height: 10),

          _RaProviderDetailsSurface(
            child: Column(
              children: [
                _RaProviderDetailRow(
                  icon: Icons.car_repair_outlined,
                  label: 'Assistance',
                  value: requestIssueLabel(data),
                ),

                if (vehicle.isNotEmpty) ...[
                  const _RaProviderDetailsDivider(),
                  _RaProviderDetailRow(
                    icon: Icons.directions_car_outlined,
                    label: 'Vehicle',
                    value: vehicle,
                  ),
                ],

                if (description.trim().isNotEmpty) ...[
                  const _RaProviderDetailsDivider(),
                  _RaProviderDetailRow(
                    icon: Icons.description_outlined,
                    label: 'Description',
                    value: description,
                  ),
                ],

                if (notes.trim().isNotEmpty) ...[
                  const _RaProviderDetailsDivider(),
                  _RaProviderDetailRow(
                    icon: Icons.sticky_note_2_outlined,
                    label: 'Additional notes',
                    value: notes,
                  ),
                ],

                if (data['partsPreference'] != null) ...[
                  const _RaProviderDetailsDivider(),
                  _RaProviderDetailRow(
                    icon: Icons.settings_suggest_outlined,
                    label: 'Parts preference',
                    value: '${data['partsPreference']}',
                  ),
                ],
              ],
            ),
          ),

          if (vehiclePhotos.isNotEmpty) ...[
            const SizedBox(height: 22),

            const _RaProviderDetailHeading(
              title: 'Driver photos',
              subtitle: 'Photos submitted with the breakdown request.',
            ),

            const SizedBox(height: 10),

            _RaProviderPhotoGallery(photos: vehiclePhotos),
          ],

          const SizedBox(height: 22),

          const _RaProviderDetailHeading(
            title: 'Breakdown location',
            subtitle:
                'Use the confirmed request location when travelling to the driver.',
          ),

          const SizedBox(height: 10),

          if (hasCoordinates)
            _RaProviderLocationCard(
              latitude: latitude,
              longitude: longitude,
              location: location,
              landmark: landmark,
            )
          else
            _RaProviderDetailsSurface(
              child: _RaProviderDetailRow(
                icon: Icons.location_off_outlined,
                label: 'Location',
                value: location,
              ),
            ),

          const SizedBox(height: 22),

          const _RaProviderDetailHeading(
            title: 'Pricing',
            subtitle:
                'Only approved charges should form part of the final bill.',
          ),

          const SizedBox(height: 10),

          _RaProviderPricingCard(
            serviceFee: serviceFee,
            travelFee: travelFee,
            extraFee: extraFee,
            estimatedCost: estimatedCost,
            finalCost: finalCost,
            money: money,
          ),

          if (data['workflowVersion'] == 2) ...[
            const SizedBox(height: 12),
            QuoteOffers(requestId: requestId),
          ],

          if (active) ...[
            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  push(
                    context,
                    ProviderActiveJobScreen(
                      requestId: requestId,
                      requestData: data,
                    ),
                  );
                },
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('Resume Active Job'),
              ),
            ),
          ],

          if (searching) ...[
            const SizedBox(height: 22),

            _RaProviderQuoteActions(requestId: requestId, data: data),
          ],

          if (rawStatus == 'completed') ...[
            const SizedBox(height: 22),

            ServiceWarranty(requestId: requestId, job: data),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  push(context, InvoiceScreen(requestId: requestId));
                },
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('View Invoice'),
              ),
            ),
          ],

          const SizedBox(height: 25),

          _RaProviderVehicleHistory(
            requestId: requestId,
            registration: data['registration'] as String? ?? '',
          ),
        ],
      ),
    );
  }
}

class _RaProviderCaseHero extends StatelessWidget {
  const _RaProviderCaseHero({
    required this.requestId,
    required this.status,
    required this.tone,
    required this.issue,
    required this.date,
    required this.priority,
  });

  final String requestId;
  final String status;
  final RaTone tone;
  final String issue;
  final String date;
  final String priority;

  @override
  Widget build(BuildContext context) {
    return RaProviderSummaryCard(
      title: issue,
      message: date,
      icon: Icons.build_outlined,
      status: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          StatusPill(label: status, tone: tone),
          if (isHighPriority(priority))
            StatusPill(
              label: requestPriorityLabel(priority),
              tone: RaTone.warning,
            ),
        ],
      ),
      footer: Text(
        'JOB $requestId',
        style: _providerText(context, size: 12, muted: true),
      ),
    );
  }
}

class _RaProviderDetailHeading extends StatelessWidget {
  const _RaProviderDetailHeading({required this.title, required this.subtitle});

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
            letterSpacing: -.3,
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

class _RaProviderDriverCard extends StatelessWidget {
  const _RaProviderDriverCard({
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

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF0D2237)
            : Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ProfileInitials(name: name, radius: 24),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      phone.trim().isEmpty ? 'Phone unavailable' : phone,
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
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: phone.trim().isEmpty
                      ? null
                      : () {
                          showCallPrompt(context, name: name, number: phone);
                        },
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
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
                  icon: _UnreadChatIcon(
                    requestId: requestId,
                    seenField: 'providerMessagesSeenAt',
                  ),
                  label: const Text('Message'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RaProviderDetailsSurface extends StatelessWidget {
  const _RaProviderDetailsSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: RaProviderCard(child: child),
    );
  }
}

class _RaProviderDetailRow extends StatelessWidget {
  const _RaProviderDetailRow({
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
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: colors.primary),
          ),
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
                    fontSize: 14,
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

class _RaProviderDetailsDivider extends StatelessWidget {
  const _RaProviderDetailsDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 47,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: .35),
    );
  }
}

class _RaProviderPhotoGallery extends StatelessWidget {
  const _RaProviderPhotoGallery({required this.photos});

  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          try {
            return ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.memory(
                base64Decode(photos[index]),
                width: 110,
                height: 110,
                fit: BoxFit.cover,
              ),
            );
          } catch (_) {
            return Container(
              width: 110,
              height: 110,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.broken_image_outlined),
            );
          }
        },
      ),
    );
  }
}

class _RaProviderLocationCard extends StatelessWidget {
  const _RaProviderLocationCard({
    required this.latitude,
    required this.longitude,
    required this.location,
    required this.landmark,
  });

  final double latitude;
  final double longitude;
  final String location;
  final String landmark;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: SizedBox(
            height: 210,
            child: MapMock(position: LatLng(latitude, longitude)),
          ),
        ),
        const SizedBox(height: 9),
        _RaProviderDetailsSurface(
          child: Column(
            children: [
              _RaProviderDetailRow(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: location,
              ),
              if (landmark.trim().isNotEmpty) ...[
                const _RaProviderDetailsDivider(),
                _RaProviderDetailRow(
                  icon: Icons.signpost_outlined,
                  label: 'Landmark',
                  value: landmark,
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    openMapNavigation(
                      context,
                      latitude: latitude,
                      longitude: longitude,
                    );
                  },
                  icon: const Icon(Icons.navigation_outlined),
                  label: const Text('Open Navigation'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RaProviderPricingCard extends StatelessWidget {
  const _RaProviderPricingCard({
    required this.serviceFee,
    required this.travelFee,
    required this.extraFee,
    required this.estimatedCost,
    required this.finalCost,
    required this.money,
  });

  final int serviceFee;
  final int travelFee;
  final int extraFee;
  final int estimatedCost;
  final int? finalCost;

  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    return _RaProviderDetailsSurface(
      child: Column(
        children: [
          _RaProviderMoneyRow(label: 'Service', amount: money(serviceFee)),
          _RaProviderMoneyRow(
            label: 'Travel / dispatch',
            amount: money(travelFee),
          ),
          _RaProviderMoneyRow(label: 'Additional', amount: money(extraFee)),
          const Divider(),
          _RaProviderMoneyRow(
            label: finalCost == null ? 'Approved total' : 'Final total',
            amount: money(finalCost ?? estimatedCost),
            strong: true,
          ),
        ],
      ),
    );
  }
}

class _RaProviderMoneyRow extends StatelessWidget {
  const _RaProviderMoneyRow({
    required this.label,
    required this.amount,
    this.strong = false,
  });

  final String label;
  final String amount;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: strong ? colors.onSurface : colors.onSurfaceVariant,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.plusJakartaSans(
              fontSize: strong ? 16 : 14,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaProviderQuoteActions extends StatefulWidget {
  const _RaProviderQuoteActions({required this.requestId, required this.data});

  final String requestId;
  final Map<String, dynamic> data;

  @override
  State<_RaProviderQuoteActions> createState() =>
      _RaProviderQuoteActionsState();
}

class _RaProviderQuoteActionsState extends State<_RaProviderQuoteActions> {
  bool busy = false;

  Future<void> _dismiss() async {
    if (busy) return;

    setState(() {
      busy = true;
    });

    try {
      await RequestService().rejectRequest(widget.requestId);

      if (mounted) {
        Navigator.maybePop(context);
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to dismiss this request.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> _quote() async {
    if (busy) return;

    final quote = await requestProviderQuote(context, widget.data);

    if (quote == null || !mounted) {
      return;
    }

    setState(() {
      busy = true;
    });

    try {
      await RequestService().acceptRequest(
        widget.requestId,
        serviceFee: quote['serviceFee'] as int,
        travelFee: quote['travelFee'] as int,
        extraFee: quote['extraFee'] as int,
        providerDistanceKm: quote['providerDistanceKm'] as double,
        quoteNotes: quote['quoteNotes'] as String,
        quoteType: quote['quoteType'] as String,
        warrantyDays: quote['warrantyDays'] as int,
        warrantyTerms: quote['warrantyTerms'] as String,
      );

      if (!mounted) return;

      if (widget.data['workflowVersion'] == 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offer sent. Waiting for driver selection.'),
          ),
        );

        return;
      }

      final accepted = Map<String, dynamic>.from(widget.data)
        ..addAll(quote)
        ..['dispatchFee'] = quote['travelFee']
        ..['estimatedCost'] =
            (quote['serviceFee'] as int) +
            (quote['travelFee'] as int) +
            (quote['extraFee'] as int)
        ..['status'] = 'accepted';

      replace(
        context,
        ProviderActiveJobScreen(
          requestId: widget.requestId,
          requestData: accepted,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().contains('Complete your active job')
                ? 'Complete your active job before accepting another request.'
                : 'This request is no longer available.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: busy ? null : _dismiss,
            child: const Text('Dismiss'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: busy ? null : _quote,
            icon: busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.request_quote_outlined),
            label: const Text('Review & Quote'),
          ),
        ),
      ],
    );
  }
}

class _RaProviderVehicleHistory extends StatelessWidget {
  const _RaProviderVehicleHistory({
    required this.requestId,
    required this.registration,
  });

  final String requestId;
  final String registration;

  @override
  Widget build(BuildContext context) {
    if (registration.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: signedIn ? RequestService().watchProviderRequests() : null,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final previous = snapshot.data!.docs
            .where((request) {
              final data = request.data();

              return request.id != requestId &&
                  data['registration'] == registration &&
                  data['status'] == 'completed';
            })
            .take(3)
            .toList();

        if (previous.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _RaProviderDetailHeading(
              title: 'Previous vehicle services',
              subtitle: 'Past completed RoadAssist jobs for this registration.',
            ),
            const SizedBox(height: 10),
            _RaProviderDetailsSurface(
              child: Column(
                children: [
                  for (var index = 0; index < previous.length; index++) ...[
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const IconBadge(
                          Icons.history_outlined,
                          size: 38,
                        ),
                        title: Text(
                          requestIssueLabel(previous[index].data()),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(_historyDate(previous[index].data())),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          push(
                            context,
                            ProviderRequestDetailsScreen(
                              requestId: previous[index].id,
                              data: previous[index].data(),
                            ),
                          );
                        },
                      ),
                    ),
                    if (index < previous.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _historyDate(Map<String, dynamic> data) {
    final value = (data['completedAt'] as Timestamp?)?.toDate().toLocal();

    if (value == null) {
      return 'Completed service';
    }

    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }
}
