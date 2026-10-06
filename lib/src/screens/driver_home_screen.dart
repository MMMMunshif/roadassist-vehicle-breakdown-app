part of '../screens.dart';

// ============================================================================
// GLASS DESIGN HELPERS
// ============================================================================

const _glassNavyTop = Color(0xFF0A2250);
const _glassNavyMid = Color(0xFF0F3A82);
const _glassBlueBottom = Color(0xFF1C5BC0);

/// Frosted-glass container (blur + translucent gradient + light border).
class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.padding = const EdgeInsets.all(RaSpace.md),
    this.radius = 20,
    this.onTap,
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final base = tint ?? Colors.white;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                base.withValues(alpha: 0.22),
                base.withValues(alpha: 0.07),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass quick-action tile with optional count badge.
class _GlassQuickAction extends StatelessWidget {
  const _GlassQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _Glass(
          onTap: onTap,
          radius: 22,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (count != null && count! > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              ),
              child: Text(
                count! > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Section heading for the dark glass background.
class _GlassSectionTitle extends StatelessWidget {
  const _GlassSectionTitle(this.title, {this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF9CC7FF),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            child: Text(
              action!,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

/// Makes existing themed widgets readable on the dark glass background.
Widget _onGlass(BuildContext context, Widget child) {
  final theme = Theme.of(context);
  return Theme(
    data: theme.copyWith(
      brightness: Brightness.dark,
      colorScheme: theme.colorScheme.copyWith(
        brightness: Brightness.dark,
        onSurface: Colors.white,
        onSurfaceVariant: Colors.white70,
      ),
      dividerColor: Colors.white.withValues(alpha: 0.18),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.12),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
        ),
      ),
    ),
    child: child,
  );
}

// ============================================================================
// SCREEN
// ============================================================================

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  String locationLabel = 'Galle Road, Colombo 03, Sri Lanka';
  bool updatingLocation = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  locationProfileSubscription;

  @override
  void initState() {
    super.initState();
    if (signedIn) {
      locationProfileSubscription = AuthService().watchCurrentProfile().listen((
        snapshot,
      ) {
        final saved = snapshot.data()?['currentLocationLabel'] as String?;
        if (mounted && saved != null && saved.trim().isNotEmpty) {
          setState(() => locationLabel = saved);
        }
      });
    }
  }

  @override
  void dispose() {
    locationProfileSubscription?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LOGIC (unchanged)
  // ---------------------------------------------------------------------------

  Future<void> saveLocation(
    String label, {
    double? latitude,
    double? longitude,
  }) async {
    setState(() => locationLabel = label);
    if (signedIn) {
      await AuthService().updateCurrentProfile({
        'currentLocationLabel': label,
        'currentLatitude': ?latitude,
        'currentLongitude': ?longitude,
      });
    }
  }

  Future<void> useCurrentHomeLocation() async {
    setState(() => updatingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationServiceDisabledException();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const PermissionDeniedException(
          'Location permission is required.',
        );
      }
      final position = await Geolocator.getCurrentPosition();
      var label =
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      try {
        final places = await Geocoding().placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (places.isNotEmpty) {
          final place = places.first;
          label =
              [
                    place.street,
                    place.locality,
                    place.administrativeArea,
                    place.country,
                  ]
                  .whereType<String>()
                  .where((part) => part.trim().isNotEmpty)
                  .toSet()
                  .join(', ');
        }
      } catch (_) {
        // Browser geocoding may be unavailable; coordinates remain accurate.
      }
      await saveLocation(
        label,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current location updated.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update location: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => updatingLocation = false);
    }
  }

  Future<void> enterLocationManually() async {
    final controller = TextEditingController(text: locationLabel);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Current Location'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Street, city or landmark',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && value.isNotEmpty) await saveLocation(value);
  }

  Future<void> changeHomeLocation() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const IconBadge(Icons.my_location_outlined),
              title: const Text('Use current GPS location'),
              onTap: () => Navigator.pop(context, 'gps'),
            ),
            ListTile(
              leading: const IconBadge(Icons.edit_location_alt_outlined),
              title: const Text('Enter location manually'),
              onTap: () => Navigator.pop(context, 'manual'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'gps') await useCurrentHomeLocation();
    if (action == 'manual') await enterLocationManually();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        const ServiceNotice(),
        DashboardHeader(
          child: Column(
            children: [
              Row(
                children: [
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseAuth.instance.currentUser == null
                        ? null
                        : AuthService().watchCurrentProfile(),
                    builder: (context, snapshot) {
                      final name =
                          snapshot.data?.data()?['displayName'] as String? ??
                          FirebaseAuth.instance.currentUser?.displayName ??
                          'Driver';
                      final photoData =
                          snapshot.data?.data()?['photoData'] as String?;
                      return Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                        ),
                        child: photoData == null || photoData.isEmpty
                            ? ProfileInitials(
                                name: name,
                                radius: 24,
                                background: Colors.white,
                              )
                            : ClipOval(
                                child: Image.memory(
                                  base64Decode(photoData),
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                ),
                              ),
                      );
                    },
                  ),
                  const SizedBox(width: RaSpace.md),
                  Expanded(
                    child:
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseAuth.instance.currentUser == null
                              ? null
                              : AuthService().watchCurrentProfile(),
                          builder: (context, snapshot) {
                            final name =
                                snapshot.data?.data()?['displayName']
                                    as String? ??
                                FirebaseAuth
                                    .instance
                                    .currentUser
                                    ?.displayName ??
                                'Driver';
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'WELCOME BACK',
                                  style: RaText.eyebrow.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                  ),
                  const _ChatInbox(isProvider: false, buttonOnly: true),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: signedIn
                        ? RequestService().watchDriverRequests()
                        : null,
                    builder: (context, snapshot) {
                      return StreamBuilder<
                        DocumentSnapshot<Map<String, dynamic>>
                      >(
                        stream: signedIn
                            ? AuthService().watchCurrentProfile()
                            : null,
                        builder: (context, profileSnapshot) {
                          final seenAt =
                              profileSnapshot.data
                                      ?.data()?['notificationsSeenAt']
                                  as Timestamp?;
                          final count =
                              snapshot.data?.docs.where((doc) {
                                final updatedAt =
                                    doc.data()['updatedAt'] as Timestamp?;
                                return doc.data()['status'] != 'searching' &&
                                    (seenAt == null ||
                                        (updatedAt?.compareTo(seenAt) ?? 1) >
                                            0);
                              }).length ??
                              0;
                          return Badge(
                            isLabelVisible: count > 0,
                            label: Text(count > 9 ? '9+' : '$count'),
                            child: IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.16,
                                ),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(44, 44),
                              ),
                              tooltip: 'Notifications',
                              onPressed: () {
                                if (signedIn) {
                                  push(
                                    context,
                                    const DriverNotificationsScreen(),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Sign in to view request notifications.',
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.notifications_none),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: RaSpace.md),
              Container(
                padding: const EdgeInsets.all(RaSpace.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(RaRadius.md),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: updatingLocation ? null : changeHomeLocation,
                  borderRadius: BorderRadius.circular(RaRadius.md),
                  child: Row(
                    children: [
                      const IconBadge(Icons.location_on_outlined, size: 36),
                      const SizedBox(width: RaSpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CURRENT LOCATION',
                              style: TextStyle(
                                color: raMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              locationLabel,
                              style: RaText.title.copyWith(color: raInk),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (updatingLocation)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(
                          Icons.edit_location_alt_outlined,
                          color: raBlue,
                          size: 21,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(RaSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(RaSpace.lg),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF182733)
                      : const Color(0xFFF3F9FE),
                  borderRadius: BorderRadius.circular(RaRadius.lg),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                      child: photoData == null || photoData.isEmpty
                          ? ProfileInitials(
                              name: name,
                              radius: 24,
                              background: Colors.white,
                            )
                          : ClipOval(
                              child: Image.memory(
                                base64Decode(photoData),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            ),
                    ),
                    const SizedBox(width: RaSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WELCOME BACK',
                            style: RaText.eyebrow.copyWith(
                              color: Colors.white70,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const _ChatInbox(isProvider: false, buttonOnly: true),
                    const SizedBox(width: RaSpace.xs),
                    _buildNotificationButton(context, seenAt),
                  ],
                );
              },
            ),
            const SizedBox(height: RaSpace.md),
            _buildLocationCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationButton(BuildContext context, Timestamp? seenAt) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: signedIn ? RequestService().watchDriverRequests() : null,
      builder: (context, snapshot) {
        final count =
            snapshot.data?.docs.where((doc) {
              final updatedAt = doc.data()['updatedAt'] as Timestamp?;
              return doc.data()['status'] != 'searching' &&
                  (seenAt == null || (updatedAt?.compareTo(seenAt) ?? 1) > 0);
            }).length ??
            0;
        return Badge(
          isLabelVisible: count > 0,
          label: Text(count > 9 ? '9+' : '$count'),
          child: IconButton(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              foregroundColor: Colors.white,
              minimumSize: const Size(44, 44),
            ),
            tooltip: 'Notifications',
            onPressed: () {
              if (signedIn) {
                push(context, const DriverNotificationsScreen());
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sign in to view request notifications.'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.notifications_none),
          ),
        );
      },
    );
  }

  Widget _buildLocationCard(BuildContext context) {
    return _Glass(
      radius: 18,
      onTap: updatingLocation ? null : changeHomeLocation,
      padding: const EdgeInsets.symmetric(
        horizontal: RaSpace.md,
        vertical: RaSpace.sm + 2,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(width: RaSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CURRENT LOCATION',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  locationLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: RaSpace.sm),
          if (updatingLocation)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            )
          else
            const Icon(
              Icons.edit_location_alt_outlined,
              color: Color(0xFF9CC7FF),
              size: 22,
            ),
        ],
      ),
    );
  }

  Widget _buildSosCard(BuildContext context) {
    return _Glass(
      radius: 22,
      padding: const EdgeInsets.all(RaSpace.md),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: raDangerPale,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sos_outlined, color: raDanger, size: 28),
          ),
          const SizedBox(width: RaSpace.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need roadside help?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Send your location to nearby providers.',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: RaSpace.sm),
          FilledButton(
            onPressed: () => push(context, const AssistanceTypeScreen()),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              minimumSize: const Size(88, 44),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Get Help',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: signedIn ? RequestService().watchDriverRequests() : null,
      builder: (context, snapshot) {
        final requestCount = snapshot.data?.docs.length;
        return Row(
          children: [
            Expanded(
              child: _GlassQuickAction(
                icon: Icons.person_search_outlined,
                label: 'Providers',
                // TODO: pass the real online-provider count here
                count: null,
                onTap: () => push(context, const ProviderDirectoryScreen()),
              ),
            ),
            const SizedBox(width: RaSpace.md),
            Expanded(
              child: _GlassQuickAction(
                icon: Icons.receipt_long_outlined,
                label: 'Requests',
                count: requestCount,
                onTap: () => push(context, const HistoryScreen()),
              ),
            ),
            const SizedBox(width: RaSpace.md),
            Expanded(
              child: _GlassQuickAction(
                icon: Icons.support_agent_outlined,
                label: 'Support',
                // TODO: pass open support ticket count here
                count: null,
                onTap: () =>
                    push(context, const SupportScreen(isProvider: false)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMyRequests(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: signedIn ? RequestService().watchDriverRequests() : null,
      builder: (context, snapshot) {
        if (!signedIn) {
          return _onGlass(
            context,
            const InlineMessage(
              icon: Icons.login_outlined,
              text: 'Sign in to view and track your requests.',
            ),
          );
        }
        if (snapshot.hasError) {
          return _onGlass(
            context,
            const InlineMessage(
              icon: Icons.cloud_off_outlined,
              text: 'Unable to load your requests.',
            ),
          );
        }
        if (!snapshot.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              minHeight: 4,
              color: Color(0xFF9CC7FF),
              backgroundColor: Colors.white12,
            ),
          );
        }
        if (snapshot.data!.docs.isEmpty) {
          return _onGlass(
            context,
            const InlineMessage(
              icon: Icons.receipt_long_outlined,
              text: 'No assistance requests yet.',
            ),
          );
        }
        final requests = snapshot.data!.docs;
        final active = requests.where((request) {
          return const [
            'searching',
            'accepted',
            'en_route',
            'arrived',
          ].contains(request.data()['status']);
        });
        return _onGlass(
          context,
          _DriverRequestPreview(
            request: active.isEmpty ? requests.first : active.first,
          ),
        );
      },
    );
  }

  Widget _buildEmergencyContacts(BuildContext context) {
    return _Glass(
      radius: 22,
      padding: EdgeInsets.zero,
      child: _onGlass(
        context,
        Column(
          children: [
            ContactTile(
              'Police Emergency',
              '119',
              onTap: () => showCallPrompt(
                context,
                name: 'Police Emergency',
                number: '119',
              ),
            ),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.15)),
            ContactTile(
              'Suwa Seriya Ambulance',
              '1990',
              onTap: () => showCallPrompt(
                context,
                name: 'Suwa Seriya Ambulance',
                number: '1990',
              ),
            ),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.15)),
            const _DriverEmergencyContactTile(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_glassNavyTop, _glassNavyMid, _glassBlueBottom],
      ),
    ),
    child: SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(context),
          Padding(
            padding: const EdgeInsets.all(RaSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSosCard(context),
                const SizedBox(height: RaSpace.lg),
                _buildQuickActions(context),
                const SizedBox(height: RaSpace.xxl),
                _GlassSectionTitle(
                  'Nearby Assistance',
                  action: 'See All',
                  onAction: () =>
                      push(context, const ProviderDirectoryScreen()),
                ),
                const SizedBox(height: RaSpace.md),
                _onGlass(context, const _NearbyProvidersPreview()),
                const SizedBox(height: RaSpace.xxl),
                const _GlassSectionTitle('My Requests'),
                const SizedBox(height: RaSpace.md),
                _buildMyRequests(context),
                const SizedBox(height: RaSpace.xxl),
                const _GlassSectionTitle('Emergency Contacts'),
                const SizedBox(height: RaSpace.md),
                _buildEmergencyContacts(context),
                const SizedBox(height: RaSpace.xl),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
