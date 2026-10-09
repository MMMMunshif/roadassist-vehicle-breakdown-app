part of '../../screens.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  Future<void> editContact(BuildContext context, String currentContact) async {
    final formKey = GlobalKey<FormState>();

    var updatedContact = currentContact == 'Not added' ? '' : currentContact;

    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            0,
            18,
            MediaQuery.of(sheetContext).viewInsets.bottom + 18,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 47,
                      height: 47,
                      decoration: BoxDecoration(
                        color: colors.error.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.contact_emergency_outlined,
                        color: colors.error,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Emergency contact',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Save a trusted contact for roadside situations.',
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
                const SizedBox(height: 18),
                TextFormField(
                  initialValue: updatedContact,
                  autofocus: true,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    hintText: '+94 77 123 4567',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: validateSriLankaPhone,
                  onChanged: (value) {
                    updatedContact = value;
                  },
                  onFieldSubmitted: (_) {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(
                        sheetContext,
                        normalizeSriLankaPhone(updatedContact),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) {
                      return;
                    }

                    Navigator.pop(
                      sheetContext,
                      normalizeSriLankaPhone(updatedContact),
                    );
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save Contact'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (value == null || value.isEmpty || !context.mounted) {
      return;
    }

    try {
      await AuthService().updateCurrentProfile({'emergencyContact': value});

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Emergency contact saved.')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save emergency contact: $error'),
          backgroundColor: raDanger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RaDriverScaffold(
      appBar: AppBar(title: const RaDriverAppBarTitle('Emergency')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const _RaEmergencyHero(),
          const SizedBox(height: 20),
          const Text(
            'Sri Lanka emergency services',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Numbers are available offline. Tap Call to open your phone dialer.',
          ),
          const SizedBox(height: 12),
          for (final item in const [
            (
              'Suwa Seriya Ambulance',
              '1990',
              Icons.medical_services_outlined,
              'Free emergency ambulance',
            ),
            (
              'Police Emergency',
              '119',
              Icons.local_police_outlined,
              'Immediate police assistance',
            ),
            (
              'Fire & Rescue',
              '110',
              Icons.local_fire_department_outlined,
              'Fire and rescue emergency',
            ),
            (
              'Disaster Management',
              '117',
              Icons.flood_outlined,
              'Disaster emergency assistance',
            ),
          ]) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          item.$3,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$1,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(item.$4),
                            ],
                          ),
                        ),
                        Text(
                          item.$2,
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () async {
                        try {
                          final opened = await launchUrl(
                            Uri(scheme: 'tel', path: item.$2),
                          );
                          if (!opened && context.mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Unable to open dialer. Call ${item.$2} from your phone.',
                                ),
                              ),
                            );
                        } catch (_) {
                          if (context.mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Call ${item.$2} from your phone dialer.',
                                ),
                              ),
                            );
                        }
                      },
                      icon: const Icon(Icons.call_outlined),
                      label: Text('Call ${item.$2}'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          const _EmergencyLiveLocation(),
          const SizedBox(height: 18),
          if (signedIn)
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: AuthService().watchCurrentProfile(),
              builder: (context, snapshot) {
                final contact =
                    snapshot.data?.data()?['emergencyContact']?.toString() ??
                    '';
                final configured = contact.isNotEmpty && contact != 'Not added';
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Trusted contact',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          snapshot.hasError
                              ? 'Unable to load your saved contact.'
                              : configured
                              ? contact
                              : 'Add someone you trust for emergencies.',
                        ),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const LinearProgressIndicator(),
                        const SizedBox(height: 10),
                        if (configured)
                          FilledButton.icon(
                            onPressed: () => showCallPrompt(
                              context,
                              name: 'Trusted contact',
                              number: contact,
                            ),
                            icon: const Icon(Icons.call),
                            label: const Text('Call Trusted Contact'),
                          ),
                        TextButton(
                          onPressed: snapshot.hasError
                              ? null
                              : () => editContact(context, contact),
                          child: Text(
                            configured ? 'Change Contact' : 'Add Contact',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          const SafetyBox(),
        ],
      ),
    );
  }
}

class _EmergencyLiveLocation extends StatefulWidget {
  const _EmergencyLiveLocation();
  @override
  State<_EmergencyLiveLocation> createState() => _EmergencyLiveLocationState();
}

class _EmergencyLiveLocationState extends State<_EmergencyLiveLocation> {
  String? location;
  String? error;
  bool loading = false;

  Future<void> locate() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled())
        throw StateError('Turn on location services and try again.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        throw StateError('Allow location access in your phone settings.');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (mounted)
        setState(
          () => location =
              'https://maps.google.com/?q=${position.latitude},${position.longitude}',
        );
    } catch (_) {
      if (mounted)
        setState(
          () => error =
              'Location unavailable. Check GPS and location permission, then try again.',
        );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Share your location',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const Text(
            'Get your current GPS location before copying or sharing. Refresh if you move.',
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (location != null) SelectableText(location!),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: loading ? null : locate,
            icon: const Icon(Icons.my_location),
            label: Text(
              loading ? 'Getting location...' : 'Get / Refresh Location',
            ),
          ),
          if (location != null) ...[
            OutlinedButton.icon(
              onPressed: () => copyLocation(context, location!),
              icon: const Icon(Icons.copy),
              label: const Text('Copy Location'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(
                  'sms:?body=${Uri.encodeComponent('I need assistance. My location: $location')}',
                );
                try {
                  if (!await launchUrl(uri) && context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Messaging unavailable. Use Copy Location instead.',
                        ),
                      ),
                    );
                } catch (_) {
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Messaging unavailable. Use Copy Location instead.',
                        ),
                      ),
                    );
                }
              },
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share via SMS'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _RaEmergencyHero extends StatelessWidget {
  const _RaEmergencyHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD8362A), Color(0xFFA92720)],
        ),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -28,
            child: Icon(
              Icons.sos_rounded,
              size: 120,
              color: Colors.white.withValues(alpha: .07),
            ),
          ),
          Row(
            children: [
              Container(
                width: 51,
                height: 51,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.health_and_safety_outlined,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency assistance',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'For immediate danger, contact emergency services before continuing with RoadAssist.',
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
        ],
      ),
    );
  }
}
