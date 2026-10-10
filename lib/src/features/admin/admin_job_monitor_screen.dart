part of '../../screens.dart';

class AdminJobMonitorScreen extends StatefulWidget {
  const AdminJobMonitorScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<AdminJobMonitorScreen> createState() => _AdminJobMonitorScreenState();
}

class _AdminJobMonitorScreenState extends State<AdminJobMonitorScreen> {
  late final job = FirebaseFirestore.instance
      .collection('requests')
      .doc(widget.requestId)
      .snapshots();

  String formatDate(DateTime value) {
    final local = value.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String statusLabel(String status) {
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

  RaTone statusTone(String status) {
    return switch (status) {
      'completed' => RaTone.success,
      'cancelled' => RaTone.danger,
      'searching' => RaTone.warning,
      'accepted' || 'en_route' || 'arrived' => RaTone.info,
      _ => RaTone.info,
    };
  }

  String money(num? value) {
    if (value == null || value <= 0) {
      return 'Not recorded';
    }

    final amount = value.round().toString();

    final buffer = StringBuffer();

    for (var index = 0; index < amount.length; index++) {
      if (index > 0 && (amount.length - index) % 3 == 0) {
        buffer.write(',');
      }

      buffer.write(amount[index]);
    }

    return 'Rs. ${buffer.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RaAdminScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Job Monitor',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: job,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Unable to load job',
                message: 'Check your admin access and connection.',
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data();

          if (data == null) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyState(
                icon: Icons.search_off_outlined,
                title: 'Job not found',
                message: 'This assistance request is no longer available.',
              ),
            );
          }

          final status = data['status'] as String? ?? 'unknown';

          final updated = (data['updatedAt'] as Timestamp?)?.toDate();

          final active = const [
            'accepted',
            'en_route',
            'arrived',
          ].contains(status);

          final stale =
              active &&
              updated != null &&
              DateTime.now().difference(updated).inMinutes >= 60;

          final latitude = (data['latitude'] as num?)?.toDouble();

          final longitude = (data['longitude'] as num?)?.toDouble();

          final finalAmount =
              data['finalCost'] as num? ?? data['estimatedCost'] as num?;

          final driverName = data['driverName'] as String? ?? 'Driver';

          final providerName = data['providerName'] as String? ?? 'Unassigned';

          final driverPhone = data['driverPhone'] as String? ?? '';

          final providerPhone = data['providerPhone'] as String? ?? '';

          final description = data['description'] as String? ?? '';

          final location =
              data['locationLabel'] as String? ??
              data['location'] as String? ??
              'Not recorded';

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            children: [
              _AdminMonitorHero(
                requestId: widget.requestId,
                status: statusLabel(status),
                issue: requestIssueLabel(data),
                tone: statusTone(status),
              ),

              if (stale) ...[
                const SizedBox(height: 12),
                const _AdminMonitorNotice(
                  icon: Icons.schedule_outlined,
                  title: 'Job update overdue',
                  message:
                      'No recorded job update for at least one hour. Review the situation and contact participants if appropriate. This does not by itself establish misconduct.',
                  tone: raGold,
                ),
              ],

              const SizedBox(height: 23),

              const _AdminMonitorHeading(
                title: 'Participants',
                subtitle:
                    'Contact details recorded against this assistance request.',
              ),

              const SizedBox(height: 10),

              _AdminMonitorParticipant(
                title: driverName,
                role: 'Driver',
                phone: driverPhone,
              ),

              const SizedBox(height: 8),

              _AdminMonitorParticipant(
                title: providerName,
                role: 'Provider',
                phone: providerPhone,
              ),

              if (active && data['providerId'] is String) ...[
                const SizedBox(height: 9),

                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('providerDirectory')
                      .doc(data['providerId'] as String)
                      .snapshots(),
                  builder: (context, presence) {
                    if (!presence.hasData || presence.hasError) {
                      return const SizedBox.shrink();
                    }

                    final online = presence.data?.data()?['online'] == true;

                    return _AdminMonitorNotice(
                      icon: online
                          ? Icons.wifi_rounded
                          : Icons.wifi_off_rounded,
                      title: online
                          ? 'Assigned provider online'
                          : 'Assigned provider offline',
                      message: online
                          ? 'Provider directory currently reports this provider as online.'
                          : 'Provider directory currently reports this provider as offline. Contact them if a job update is overdue.',
                      tone: online ? raSuccess : raGold,
                    );
                  },
                ),
              ],

              const SizedBox(height: 23),

              const _AdminMonitorHeading(
                title: 'Job information',
                subtitle: 'Live request information from Firestore.',
              ),

              const SizedBox(height: 10),

              _AdminMonitorCard(
                children: [
                  _AdminMonitorRow(label: 'Status', value: statusLabel(status)),
                  _AdminMonitorRow(
                    label: 'Problem',
                    value: requestIssueLabel(data),
                  ),
                  _AdminMonitorRow(
                    label: 'Vehicle',
                    value:
                        [
                              data['vehicleType'] as String? ?? '',
                              data['modelYear'] as String? ?? '',
                              data['registration'] as String? ?? '',
                            ]
                            .where((value) => value.trim().isNotEmpty)
                            .join(' • ')
                            .trim()
                            .isEmpty
                        ? 'Not recorded'
                        : [
                                data['vehicleType'] as String? ?? '',
                                data['modelYear'] as String? ?? '',
                                data['registration'] as String? ?? '',
                              ]
                              .where((value) => value.trim().isNotEmpty)
                              .join(' • '),
                  ),
                  _AdminMonitorRow(label: 'Location', value: location),
                  _AdminMonitorRow(
                    label: 'Service amount',
                    value: money(finalAmount),
                    strong: true,
                  ),
                  if (updated != null)
                    _AdminMonitorRow(
                      label: 'Last recorded update',
                      value: formatDate(updated),
                    ),
                ],
              ),

              if (latitude != null && longitude != null) ...[
                const SizedBox(height: 16),

                const _AdminMonitorHeading(
                  title: 'Breakdown location',
                  subtitle: 'Location attached to this request.',
                ),

                const SizedBox(height: 10),

                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    height: 230,
                    child: MapMock(position: LatLng(latitude, longitude)),
                  ),
                ),
              ],

              if (description.trim().isNotEmpty) ...[
                const SizedBox(height: 23),

                const _AdminMonitorHeading(
                  title: 'Driver description',
                  subtitle: 'Information supplied when requesting assistance.',
                ),

                const SizedBox(height: 10),

                _AdminMonitorSurface(
                  child: Text(
                    description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      height: 1.55,
                    ),
                  ),
                ),
              ],

              if (status == 'completed') ...[
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      push(context, InvoiceScreen(requestId: widget.requestId));
                    },
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Review Invoice & Approvals'),
                  ),
                ),
              ],

              const SizedBox(height: 14),

              const _AdminMonitorNotice(
                icon: Icons.visibility_outlined,
                title: 'Read-only monitoring',
                message:
                    'Admin monitoring does not change provider assignment, job status or service price. Use the agreed support process when intervention is required.',
                tone: raBlue,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminMonitorHero extends StatelessWidget {
  const _AdminMonitorHero({
    required this.requestId,
    required this.status,
    required this.issue,
    required this.tone,
  });

  final String requestId;
  final String status;
  final String issue;
  final RaTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _providerSurface(context),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 47,
                height: 47,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.route_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              Flexible(
                child: StatusPill(label: status, tone: tone),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            issue,
            style: GoogleFonts.plusJakartaSans(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -.4,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'JOB $requestId',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminMonitorHeading extends StatelessWidget {
  const _AdminMonitorHeading({required this.title, required this.subtitle});

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
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AdminMonitorParticipant extends StatelessWidget {
  const _AdminMonitorParticipant({
    required this.title,
    required this.role,
    required this.phone,
  });

  final String title;
  final String role;
  final String phone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF0D2237)
            : colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      child: Row(
        children: [
          ProfileInitials(name: title, radius: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  role,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Call $role',
            onPressed: phone.trim().isEmpty
                ? null
                : () {
                    showCallPrompt(context, name: title, number: phone);
                  },
            icon: const Icon(Icons.call_outlined),
          ),
        ],
      ),
    );
  }
}

class _AdminMonitorCard extends StatelessWidget {
  const _AdminMonitorCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _AdminMonitorSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(children: children),
    );
  }
}

class _AdminMonitorSurface extends StatelessWidget {
  const _AdminMonitorSurface({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF0D2237)
            : colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      child: child,
    );
  }
}

class _AdminMonitorRow extends StatelessWidget {
  const _AdminMonitorRow({
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
      padding: const EdgeInsets.symmetric(vertical: 10),
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
                fontSize: strong ? 15 : 14,
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

class _AdminMonitorNotice extends StatelessWidget {
  const _AdminMonitorNotice({
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
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 20),
          const SizedBox(width: 9),
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
                    height: 1.45,
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
