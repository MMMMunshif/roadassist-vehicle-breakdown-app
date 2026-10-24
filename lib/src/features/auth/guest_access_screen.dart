part of '../../screens.dart';

class GuestAccessScreen extends StatefulWidget {
  const GuestAccessScreen({super.key, this.service});
  final GuestAssistanceService? service;
  @override
  State<GuestAccessScreen> createState() => _GuestAccessScreenState();
}

class _GuestAccessScreenState extends State<GuestAccessScreen>
    with WidgetsBindingObserver {
  late final api = widget.service ?? GuestAssistanceService();
  final name = TextEditingController(),
      phone = TextEditingController(),
      otp = TextEditingController();
  final registration = TextEditingController(),
      model = TextEditingController(),
      notes = TextEditingController(),
      message = TextEditingController();
  String issue = 'General Mechanic', vehicle = 'Sedan / Hatchback';
  String? requestId, submissionId, error, recoveryCode;
  Map<String, dynamic>? job;
  List<Map<String, dynamic>> messages = [];
  LatLng? location;
  DateTime? lastSync;
  bool busy = false,
      loading = true,
      enabled = false,
      verified = false,
      reading = false,
      foreground = true;
  Timer? polling;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(checkAvailability());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    polling?.cancel();
    api.dispose();
    for (final c in [name, phone, otp, registration, model, notes, message]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground && requestId != null) unawaited(refresh());
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted)
        setState(
          () => error = e is FirebaseAuthException
              ? guestPhoneError(e)
              : _workflowError(e, 'Unable to continue. Retry when connected.'),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> checkAvailability() async {
    try {
      enabled = await api.available();
      if (enabled && GuestAssistanceService.hasGuestIdentity) {
        await recover();
      }
    } catch (_) {
      error =
          'Unable to check guest availability. Emergency help is still available.';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> recover() async {
    final result = await api.send('bootstrap', {
      'name': name.text.trim(),
      'phone': normalizeSriLankaPhone(phone.text),
    });
    if (!mounted) return;
    setState(() {
      verified = true;
      recoveryCode = result['recoveryCode'] as String? ?? recoveryCode;
      name.text = result['name'] as String? ?? name.text;
      requestId = result['requestId'] as String?;
    });
    if (requestId != null) {
      await refresh();
      polling ??= Timer.periodic(const Duration(seconds: 6), (_) {
        if (foreground && !busy) unawaited(refresh());
      });
    }
  }

  Future<void> startGuest() async {
    if (name.text.trim().length < 2) throw StateError('Enter your name first.');
    final invalid = validateSriLankaPhone(phone.text);
    if (invalid != null) throw StateError(invalid);
    if (signedIn && !GuestAssistanceService.hasGuestIdentity) {
      throw StateError(
        'Sign out of your member account before using guest access.',
      );
    }
    if (!GuestAssistanceService.hasGuestIdentity) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    await recover();
  }

  Future<void> restoreGuest() async {
    if (signedIn && !GuestAssistanceService.hasGuestIdentity) {
      throw StateError('Sign out of your member account first.');
    }
    if (!GuestAssistanceService.hasGuestIdentity) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    final result = await api.send('recover', {'recoveryCode': otp.text.trim()});
    await FirebaseAuth.instance.signInWithCustomToken(
      result['token'] as String,
    );
    await recover();
  }

  Future<void> gps() async {
    if (!await Geolocator.isLocationServiceEnabled())
      throw StateError(
        'Turn on location or tap the map to choose your location.',
      );
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied)
      permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever)
      throw StateError(
        'Location permission was denied. Tap the map to select your breakdown point.',
      );
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    if (mounted) setState(() => location = LatLng(p.latitude, p.longitude));
  }

  Map<String, dynamic> get draft => {
    'issue': issue,
    'vehicleType': vehicle,
    'registration': registration.text.trim(),
    'modelYear': model.text.trim(),
    'notes': notes.text.trim(),
    'latitude': location?.latitude,
    'longitude': location?.longitude,
  };
  Future<void> chooseProvider() async {
    if (registration.text.trim().length < 3 || location == null)
      throw StateError(
        'Enter your registration and select your breakdown point.',
      );
    final result = await api.send('providers', draft);
    if (!mounted) return;
    final rows = (result['providers'] as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty)
      throw StateError(
        'No suitable provider is online nearby. Retry shortly or use Emergency help.',
      );
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .75,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Choose your provider',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Distance is straight-line. Review the confirmed visit fee next.',
            ),
            for (final row in rows)
              ListTile(
                title: Text(row['name'] as String),
                subtitle: Text(
                  '${(row['distanceKm'] as num).toStringAsFixed(1)} km away',
                ),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => Navigator.pop(context, row),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final quote = await api.send('prepare', {
      'providerId': selected['id'],
      'latitude': location!.latitude,
      'longitude': location!.longitude,
    });
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review visit fee'),
        content: Text(
          '${selected['name']}\nLKR ${quote['visitFee']} visit fee\n${(quote['distanceKm'] as num).toStringAsFixed(2)} km straight-line. Inspection, labour and approved parts are billed after service. Cash receipt is confirmed separately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Request assistance'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    submissionId ??= FirebaseFirestore.instance.collection('requests').doc().id;
    final created = await api.send('create', {
      ...draft,
      'submissionId': submissionId,
      'quoteId': quote['quoteId'],
      'providerId': selected['id'],
    });
    if (!mounted) return;
    setState(() => requestId = created['requestId'] as String);
    await refresh();
    polling ??= Timer.periodic(const Duration(seconds: 6), (_) {
      if (foreground && !busy) unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    if (reading || requestId == null || !mounted) return;
    reading = true;
    try {
      final data = await api.send('read', {'requestId': requestId});
      if (mounted)
        setState(() {
          job = Map<String, dynamic>.from(data['job'] as Map);
          messages = (data['messages'] as List)
              .map((m) => Map<String, dynamic>.from(m as Map))
              .toList();
          lastSync = DateTime.now();
          error = null;
        });
    } catch (e) {
      if (mounted)
        setState(
          () => error = _workflowError(
            e,
            'Updates unavailable. Your request is kept; retry when connected.',
          ),
        );
    } finally {
      reading = false;
    }
  }

  Future<void> act(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    await api.send(action, {'requestId': requestId, ...data});
    await refresh();
  }

  Future<void> confirmArrival() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Provider is here'),
        content: const Text(
          'Confirm only after physically meeting your assigned provider.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm arrival'),
          ),
        ],
      ),
    );
    if (yes == true) await act('arrive');
  }

  Future<void> pay() async {
    final method = await requestCheckout(
      context,
      (job!['finalCost'] as num).toInt(),
      showDemoCard: false,
    );
    if (method != null)
      await act('checkout', {
        'checkoutMethod': 'cash',
        'expectedFinalCost': job!['finalCost'],
      });
  }

  Future<void> correction() async {
    final c = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request bill correction'),
        content: TextField(
          controller: c,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Explain the charge to correct',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: const Text('Send correction'),
          ),
        ],
      ),
    );
    c.dispose();
    if (reason != null) await act('correct', {'reason': reason});
  }

  Future<void> leaveGuest({bool createAccount = false}) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          createAccount ? 'Create a Driver account?' : 'Leave guest session?',
        ),
        content: const Text(
          'This does not cancel your request. Save your recovery code before leaving; your phone number alone cannot recover it. Guest receipts are not automatically transferred to a new email account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay here'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(createAccount ? 'Continue to signup' : 'Leave session'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    polling?.cancel();
    polling = null;
    if (createAccount) {
      replace(context, const RegistrationScreen(isProvider: false));
      return;
    }
    setState(() {
      verified = false;
      job = null;
      requestId = null;
      recoveryCode = null;
      otp.clear();
      error = null;
    });
  }

  Future<void> receipt() async {
    final data = Map<String, dynamic>.from(job!);
    for (final field in ['createdAt', 'completedAt', 'serviceCompletedAt']) {
      if (data[field] is num)
        data[field] = Timestamp.fromMillisecondsSinceEpoch(
          (data[field] as num).toInt(),
        );
    }
    final invoice = ServiceInvoice.fromRequest(requestId!, data);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: .9,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: InvoiceBillView(
            invoice: invoice,
            onDownload: () => run(() async {
              final bytes = await InvoicePdfService.generate(invoice);
              await InvoicePdfService.download(bytes, invoice.filename);
            }),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => RaDriverScaffold(
    appBar: AppBar(
      title: const Text(
        'Guest assistance',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          tooltip: 'Emergency help',
          onPressed: () => push(context, const EmergencyScreen()),
          icon: const Icon(Icons.sos_outlined),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            InlineMessage(icon: Icons.info_outline, text: error!),
          if (!enabled && !loading) ...[
            const RaProviderSummaryCard(
              title: 'Emergency help is available',
              message:
                  'Guest requests need service setup. You can still open emergency help without an account.',
              icon: Icons.emergency_outlined,
            ),
            TextButton(
              onPressed: () => run(checkAvailability),
              child: const Text('Retry availability'),
            ),
          ],
          if (enabled && !verified) ...contact(),
          if (enabled && verified && recoveryCode != null) ...[
            const Text(
              'Save this private recovery code. Anyone with it can access your guest request.',
            ),
            SelectableText(recoveryCode!),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: recoveryCode!));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Recovery code copied')),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy recovery code'),
            ),
          ],
          if (enabled && verified && requestId == null) ...requestForm(),
          if (enabled && verified && requestId != null && job == null)
            FilledButton(
              onPressed: busy ? null : () => run(refresh),
              child: const Text('Load current request'),
            ),
          if (enabled && verified && job != null) ...tracking(),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => push(context, const EmergencyScreen()),
            icon: const Icon(Icons.emergency_outlined),
            label: const Text('Emergency help'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Guest access covers your current request only. No password or email account is required.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
  List<Widget> contact() => [
    const RaProviderSummaryCard(
      title: 'Help without the signup.',
      message:
          'Enter your contact details. Your provider will call to confirm; this number is not SMS verified. Only your current request is accessible.',
      icon: Icons.phone_outlined,
    ),
    const SizedBox(height: 18),
    TextField(
      controller: name,
      maxLength: 100,
      decoration: const InputDecoration(labelText: 'Your name'),
    ),
    TextField(
      controller: phone,
      keyboardType: TextInputType.phone,
      decoration: const InputDecoration(
        labelText: 'Mobile number',
        hintText: '07XXXXXXXX',
      ),
    ),
    const SizedBox(height: 12),
    const Text(
      'Your number is shared with the assigned provider for this request. No SMS is sent. Keep this browser session or save your recovery code.',
    ),
    FilledButton(
      onPressed: busy ? null : () => run(startGuest),
      child: const Text('Continue as guest'),
    ),
    const SizedBox(height: 16),
    TextField(
      controller: otp,
      decoration: const InputDecoration(
        labelText: 'Recovery code (existing request)',
      ),
    ),
    TextButton(
      onPressed: busy ? null : () => run(restoreGuest),
      child: const Text('Recover my request'),
    ),
  ];
  List<Widget> requestForm() => [
    Text(
      'What do you need help with?',
      style: Theme.of(context).textTheme.headlineSmall,
    ),
    const SizedBox(height: 16),
    DropdownButtonFormField<String>(
      initialValue: issue,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Service'),
      items: const [
        'General Mechanic',
        'Vehicle Towing',
        'Flat Tyre',
        'Battery Jumpstart',
      ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: busy ? null : (v) => setState(() => issue = v!),
    ),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(
      initialValue: vehicle,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Vehicle type'),
      items: const [
        'Sedan / Hatchback',
        'SUV',
        'Van',
        'Motorcycle',
      ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: busy ? null : (v) => setState(() => vehicle = v!),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: registration,
      maxLength: 20,
      decoration: const InputDecoration(labelText: 'Registration'),
    ),
    TextField(
      controller: model,
      maxLength: 80,
      decoration: const InputDecoration(labelText: 'Make / model (optional)'),
    ),
    TextField(
      controller: notes,
      maxLength: 500,
      decoration: const InputDecoration(
        labelText: 'Problem or nearby landmark (optional)',
      ),
    ),
    const SizedBox(height: 12),
    OutlinedButton.icon(
      onPressed: busy ? null : () => run(gps),
      icon: const Icon(Icons.my_location),
      label: const Text('Use my GPS location'),
    ),
    const Text(
      'Tap the map to select or adjust the breakdown point. GPS is not assumed.',
    ),
    SizedBox(
      height: 240,
      child: MapMock(
        position: location ?? const LatLng(6.9271, 79.8612),
        onPositionSelected: busy ? null : (p) => setState(() => location = p),
      ),
    ),
    Text(
      location == null
          ? 'No breakdown point selected'
          : 'Selected: ${location!.latitude.toStringAsFixed(5)}, ${location!.longitude.toStringAsFixed(5)}',
    ),
    const SizedBox(height: 16),
    FilledButton(
      onPressed: busy ? null : () => run(chooseProvider),
      child: const Text('Find providers & review visit fee'),
    ),
  ];
  List<Widget> tracking() {
    final j = job!, status = j['status'] as String? ?? 'searching';
    final index = [
      'accepted',
      'en_route',
      'arrived',
      'completed',
    ].indexOf(status);
    final estimate = j['workEstimate'] is Map
        ? Map<String, dynamic>.from(j['workEstimate'] as Map)
        : null;
    final received = j['providerConfirmedPayment'] == true;
    return [
      ActiveAssistanceStatusCard(
        status: index < 0 ? 0 : index,
        cancelled: status == 'cancelled',
        completionPending: j['completionState'] == 'pending',
        title: status == 'searching'
            ? 'Waiting for your provider'
            : status == 'cancelled'
            ? 'Request cancelled'
            : j['completionState'] == 'pending'
            ? 'Your final bill is ready'
            : status == 'completed'
            ? 'Service completed'
            : status.replaceAll('_', ' '),
        description:
            j['cancellationReason'] as String? ??
            'Only real provider updates change this status. Guest access is limited to this request.',
      ),
      if (lastSync != null)
        Text(
          'Last checked: ${TimeOfDay.fromDateTime(lastSync!).format(context)}',
        ),
      TextButton(
        onPressed: busy ? null : () => run(refresh),
        child: const Text('Refresh request'),
      ),
      if (j['providerId'] != null) ...[
        Text(
          j['providerName'] as String? ?? 'Assigned provider',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        OutlinedButton.icon(
          onPressed: () => showCallPrompt(
            context,
            name: j['providerName'] as String? ?? 'Provider',
            number: j['providerPhone'] as String? ?? '',
          ),
          icon: const Icon(Icons.call_outlined),
          label: const Text('Call provider'),
        ),
      ],
      if (j['providerLatitude'] is num && j['providerLongitude'] is num) ...[
        LiveLocationStatus(
          hasPosition: true,
          updatedAt: j['providerLocationUpdatedAt'] is num
              ? DateTime.fromMillisecondsSinceEpoch(
                  (j['providerLocationUpdatedAt'] as num).toInt(),
                )
              : null,
        ),
        SizedBox(
          height: 220,
          child: MapMock(
            position: LatLng(
              (j['latitude'] as num).toDouble(),
              (j['longitude'] as num).toDouble(),
            ),
            providerPosition: LatLng(
              (j['providerLatitude'] as num).toDouble(),
              (j['providerLongitude'] as num).toDouble(),
            ),
            showProviders: true,
          ),
        ),
      ],
      if (status == 'arrived' && j['arrivalConfirmedBy'] == null)
        FilledButton(
          onPressed: busy ? null : () => run(confirmArrival),
          child: const Text('Provider is here'),
        ),
      if (estimate?['status'] == 'pending')
        RaProviderCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Approve replacement parts before work'),
              Text(
                'Visit: LKR ${j['dispatchFee']} · Inspection: LKR ${estimate!['inspectionFee']} · Labour: LKR ${estimate['serviceFee']}',
              ),
              Text('Estimated total: LKR ${estimate['finalCost']}'),
              for (final item in (estimate['billItems'] as List? ?? []))
                Text(
                  '${item['label']}: LKR ${item['amount']}\n${item['reason']}',
                ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () => run(
                        () => act('decide_estimate', {
                          'revision': estimate['revision'],
                          'approve': true,
                        }),
                      ),
                child: const Text('Approve these parts'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => run(
                        () => act('decide_estimate', {
                          'revision': estimate['revision'],
                          'approve': false,
                        }),
                      ),
                child: const Text('Decline'),
              ),
            ],
          ),
        ),
      const SizedBox(height: 14),
      RaProviderCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              j['finalCost'] == null ? 'Visit fee' : 'Final service bill',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('Visit fee: LKR ${j['dispatchFee']}'),
            if (j['finalCost'] != null) ...[
              Text('Inspection: LKR ${j['inspectionFee'] ?? 0}'),
              Text('Labour: LKR ${j['serviceFee'] ?? 0}'),
              for (final item in (j['billItems'] as List? ?? []))
                Text(
                  '${item['label']}: LKR ${item['amount']}\n${item['reason']}',
                ),
              Text(
                'Total: LKR ${j['finalCost']}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(j['serviceNotes'] as String? ?? ''),
            ],
            if (j['completionState'] == 'pending') ...[
              FilledButton(
                onPressed: busy ? null : () => run(pay),
                child: const Text('Accept bill & choose cash'),
              ),
              TextButton(
                onPressed: busy ? null : () => run(correction),
                child: const Text('Request bill correction'),
              ),
            ],
            if (status == 'completed')
              Text(
                received
                    ? 'Payment receipt confirmed'
                    : j['driverReportedPayment'] == true
                    ? 'Payment reported. Do not pay again; waiting for provider receipt.'
                    : 'Payment has not been reported.',
              ),
          ],
        ),
      ),
      if (j['providerId'] != null &&
          !['completed', 'cancelled'].contains(status))
        RaDetailsDisclosure(
          storageKey: 'guest-chat',
          title: 'Message your provider',
          icon: Icons.chat_bubble_outline,
          child: Column(
            children: [
              for (final m in messages)
                ListTile(
                  title: Text(m['text'] as String? ?? ''),
                  subtitle: Text(
                    m['senderId'] == FirebaseAuth.instance.currentUser?.uid
                        ? 'You'
                        : 'Provider',
                  ),
                ),
              TextField(
                controller: message,
                maxLength: 2000,
                decoration: const InputDecoration(labelText: 'Your message'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () => run(() async {
                        await act('message', {'text': message.text});
                        message.clear();
                      }),
                child: const Text('Send message'),
              ),
            ],
          ),
        ),
      if (['searching', 'accepted', 'en_route'].contains(status))
        TextButton(
          onPressed: busy
              ? null
              : () => run(() async {
                  final reason = await requestCancellationReason(context);
                  if (reason != null) await act('cancel', {'reason': reason});
                }),
          child: const Text('Cancel assistance'),
        ),
      if (status == 'cancelled' || (status == 'completed' && received))
        OutlinedButton(
          onPressed: busy
              ? null
              : () => setState(() {
                  job = null;
                  requestId = null;
                  submissionId = null;
                  polling?.cancel();
                  polling = null;
                }),
          child: const Text('Start another guest request'),
        ),
      if (status == 'completed')
        OutlinedButton.icon(
          onPressed: busy ? null : () => run(receipt),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('View / download receipt'),
        ),
      if (status == 'completed' && received)
        TextButton(
          onPressed: busy
              ? null
              : () => run(() => leaveGuest(createAccount: true)),
          child: const Text('Create account for future requests'),
        ),
      if (status == 'completed')
        const Text(
          'For future saved vehicles and account history, create a Driver account. This guest session still retains this receipt.',
        ),
    ];
  }
}
