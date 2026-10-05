part of '../screens.dart';

class AdminPortalScreen extends StatefulWidget {
  const AdminPortalScreen({super.key});
  @override
  State<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool checking = true, allowed = false, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    unawaited(checkAccess());
  }

  Future<void> checkAccess() async {
    try {
      await AdminService().requireAdmin();
      if (mounted) setState(() => allowed = true);
    } catch (_) {
      if (mounted) setState(() => allowed = false);
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  Future<void> login() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );
      await AdminService().requireAdmin();
      if (mounted) setState(() => allowed = true);
      password.clear();
    } catch (_) {
      await FirebaseAuth.instance.signOut();
      if (mounted)
        setState(
          () => error =
              'Sign-in failed or this account has no verified admin permission.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (checking)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (allowed)
      return AdminDashboardScreen(
        onSignOut: () async {
          await AuthService().signOut();
          if (mounted) setState(() => allowed = false);
        },
      );
    return Scaffold(
      appBar: AppBar(title: const Text('RoadAssist Private Admin')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Admin sign-in', style: RaText.headline),
          const Text(
            'Use an existing verified account with permission granted by the project owner.',
          ),
          const SizedBox(height: 20),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username],
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Password'),
            onSubmitted: (_) {
              if (!busy) login();
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : login,
            child: const Text('Sign in'),
          ),
          if (busy) const LinearProgressIndicator(),
          if (error != null) Text(error!),
        ],
      ),
    );
  }
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, required this.onSignOut});
  final Future<void> Function() onSignOut;
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int tab = 0;
  final tabs = [
    'Overview',
    'Providers',
    'Users',
    'Complaints',
    'Jobs',
    'Audit',
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Admin dashboard'),
      actions: [
        IconButton(
          onPressed: widget.onSignOut,
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: ChoiceChip(
                    label: Text(tabs[i]),
                    selected: tab == i,
                    onSelected: (_) => setState(() => tab = i),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: switch (tab) {
            0 => const _AdminOverview(),
            1 => const _AdminRecords(kind: 'providers'),
            2 => const _AdminRecords(kind: 'users'),
            3 => const _AdminRecords(kind: 'complaints'),
            4 => const _AdminRecords(kind: 'jobs'),
            _ => const _AdminRecords(kind: 'audit'),
          },
        ),
      ],
    ),
  );
}

class _AdminOverview extends StatelessWidget {
  const _AdminOverview();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text('Operations overview', style: RaText.headline),
      const Text(
        'Live counts are capped at 100 records per card. Use each section to load more. No money or job status is changed by a complaint decision.',
      ),
      for (final section in [
        'users',
        'providerDirectory',
        'requests',
        'accountModeration',
      ])
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(section)
              .limit(100)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return Text('Could not load $section. Check admin access.');
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final records = snapshot.data!.docs;
            final count = section == 'providerDirectory'
                ? records.where((d) => d.data()['online'] == true).length
                : section == 'requests'
                ? records
                      .where(
                        (d) => [
                          'accepted',
                          'en_route',
                          'arrived',
                        ].contains(d.data()['status']),
                      )
                      .length
                : section == 'accountModeration'
                ? records.where((d) => d.data()['flagged'] == true).length
                : records.length;
            return Card(
              child: ListTile(
                title: Text(
                  {
                    'users': 'Users loaded',
                    'providerDirectory': 'Online providers in loaded records',
                    'requests': 'Active jobs in loaded records',
                    'accountModeration': 'Flagged accounts in loaded records',
                  }[section]!,
                ),
                trailing: Text('$count', style: RaText.numeric),
              ),
            );
          },
        ),
    ],
  );
}

class _AdminRecords extends StatefulWidget {
  const _AdminRecords({required this.kind});
  final String kind;
  @override
  State<_AdminRecords> createState() => _AdminRecordsState();
}

class _AdminRecordsState extends State<_AdminRecords> {
  int limit = 50;
  String search = '';
  bool onlyAttention = false;
  late Stream<QuerySnapshot<Map<String, dynamic>>> records;
  @override
  void initState() {
    super.initState();
    connect();
  }

  @override
  void didUpdateWidget(covariant _AdminRecords old) {
    super.didUpdateWidget(old);
    if (old.kind != widget.kind) {
      limit = 50;
      search = '';
      onlyAttention = false;
      connect();
    }
  }

  void connect() {
    final db = FirebaseFirestore.instance;
    Query<Map<String, dynamic>> query = switch (widget.kind) {
      'providers' =>
        db.collection('users').where('role', isEqualTo: 'provider'),
      'users' => db.collection('users'),
      'complaints' => db.collectionGroup('disputes'),
      'jobs' =>
        db.collection('requests').orderBy('createdAt', descending: true),
      _ => db.collection('adminAudit').orderBy('createdAt', descending: true),
    };
    records = query.limit(limit).snapshots();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextField(
          key: ValueKey(widget.kind),
          decoration: const InputDecoration(
            labelText: 'Search loaded records',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) =>
              setState(() => search = value.toLowerCase().trim()),
        ),
      ),
      if (widget.kind == 'jobs' ||
          widget.kind == 'complaints' ||
          widget.kind == 'providers')
        SwitchListTile(
          title: Text(
            widget.kind == 'jobs'
                ? 'Only active jobs'
                : widget.kind == 'providers'
                ? 'Only pending verification'
                : 'Only unresolved driver reports',
          ),
          value: onlyAttention,
          onChanged: (value) => setState(() => onlyAttention = value),
        ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: records,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return const Center(
                child: Text(
                  'Could not load records. Verify admin access and reconnect.',
                ),
              );
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs.where((d) {
              final data = d.data();
              if (onlyAttention &&
                  widget.kind == 'jobs' &&
                  !['accepted', 'en_route', 'arrived'].contains(data['status']))
                return false;
              if (onlyAttention &&
                  widget.kind == 'complaints' &&
                  data['status'] == 'resolved')
                return false;
              final searchable = [
                d.id,
                data['email'],
                data['displayName'],
                data['driverName'],
                data['providerName'],
                data['reason'],
                data['description'],
                data['target'],
                data['actor'],
                data['status'],
              ].join(' ').toLowerCase();
              return searchable.contains(search);
            }).toList();
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '${snapshot.data!.docs.length} loaded; ${docs.length} search matches. Filters apply to loaded records.',
                  ),
                ),
                for (final doc in docs)
                  if (widget.kind == 'providers' || widget.kind == 'users')
                    _AdminUserRow(
                      key: ValueKey(doc.id),
                      uid: doc.id,
                      data: doc.data(),
                      pendingOnly: widget.kind == 'providers' && onlyAttention,
                    )
                  else
                    ListTile(
                      title: Text(
                        (doc.data()['displayName'] ??
                                doc.data()['driverName'] ??
                                doc.data()['kind'] ??
                                doc.id)
                            .toString(),
                      ),
                      subtitle: Text(
                        widget.kind == 'users' || widget.kind == 'providers'
                            ? '${doc.data()['email'] ?? ''}\n${doc.data()['role']}'
                            : widget.kind == 'audit'
                            ? '${doc.data()['actor']}\n${doc.data()['reason']}'
                            : '${doc.data()['status']}\n${doc.data()['description'] ?? doc.data()['issue'] ?? ''}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => push(
                        context,
                        widget.kind == 'users' || widget.kind == 'providers'
                            ? _AdminAccountScreen(uid: doc.id)
                            : widget.kind == 'complaints'
                            ? _AdminComplaintScreen(
                                requestId: doc.reference.parent.parent!.id,
                              )
                            : widget.kind == 'jobs'
                            ? AdminJobMonitorScreen(requestId: doc.id)
                            : _AdminAuditScreen(data: doc.data()),
                      ),
                    ),
                if (snapshot.data!.docs.length == limit)
                  OutlinedButton(
                    onPressed: () => setState(() {
                      limit += 50;
                      connect();
                    }),
                    child: const Text('Load 50 more'),
                  ),
              ],
            );
          },
        ),
      ),
    ],
  );
}

Future<String?> _adminReason(BuildContext context, String title) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        maxLength: 500,
        minLines: 2,
        maxLines: 5,
        decoration: const InputDecoration(
          labelText: 'Reason (at least 10 characters)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back'),
        ),
        FilledButton(
          onPressed: () {
            if (controller.text.trim().length >= 10)
              Navigator.pop(context, controller.text.trim());
          },
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
  // Dialog closing animation may still read the controller.
  Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
  return result;
}

class _AdminAccountScreen extends StatefulWidget {
  const _AdminAccountScreen({required this.uid});
  final String uid;
  @override
  State<_AdminAccountScreen> createState() => _AdminAccountScreenState();
}

class _AdminAccountScreenState extends State<_AdminAccountScreen> {
  bool busy = false;
  late final user = FirebaseFirestore.instance
      .collection('users')
      .doc(widget.uid)
      .snapshots();
  late final moderation = FirebaseFirestore.instance
      .collection('accountModeration')
      .doc(widget.uid)
      .snapshots();
  Future<void> change(String action) async {
    final reason = await _adminReason(context, '$action account');
    if (reason == null || !mounted) return;
    setState(() => busy = true);
    try {
      await AdminService().moderate(
        widget.uid,
        reason: reason,
        verification: action == 'Verify'
            ? 'verified'
            : action == 'Reject'
            ? 'rejected'
            : null,
        status: action == 'Suspend'
            ? 'suspended'
            : action == 'Restore'
            ? 'active'
            : null,
        flagged: action == 'Flag'
            ? true
            : action == 'Clear flag'
            ? false
            : null,
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Action failed. Check admin permission and connection.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Account review')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: user,
      builder: (context, snapshot) =>
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: moderation,
            builder: (context, review) {
              if (snapshot.hasError || review.hasError)
                return const Center(child: Text('Could not load account.'));
              if (!snapshot.hasData || !review.hasData)
                return const Center(child: CircularProgressIndicator());
              final data = snapshot.data!.data();
              if (data == null)
                return const Center(child: Text('Profile no longer exists.'));
              final decision = review.data!.data() ?? {};
              final own = FirebaseAuth.instance.currentUser?.uid == widget.uid;
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    data['displayName'] as String? ?? widget.uid,
                    style: RaText.headline,
                  ),
                  SummaryRow('Email', data['email'] as String? ?? ''),
                  SummaryRow('Role', data['role'] as String? ?? ''),
                  SummaryRow(
                    'Access',
                    decision['status'] as String? ?? 'active',
                  ),
                  SummaryRow(
                    'Verification',
                    decision['verification'] as String? ?? 'pending',
                  ),
                  SummaryRow('Flagged', '${decision['flagged'] ?? false}'),
                  if (decision['reason'] != null)
                    Text('Last reason: ${decision['reason']}'),
                  const Text(
                    'Suspension blocks app database operations. It does not disable Firebase login. Check active jobs before suspending a participant.',
                  ),
                  if (data['role'] == 'provider') ...[
                    Text(
                      'Services: ${(data['services'] as List? ?? []).join(', ')}',
                    ),
                    if (data['photoData'] is String)
                      RevisionEvidencePhotos(
                        photos: [data['photoData'] as String],
                      ),
                    const Text(
                      'Verification is a manual review of the available profile. A document submission workflow is not yet available.',
                    ),
                  ],
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final action in [
                        if (data['role'] == 'provider') ...['Verify', 'Reject'],
                        'Suspend',
                        'Restore',
                        'Flag',
                        'Clear flag',
                      ])
                        OutlinedButton(
                          onPressed:
                              busy ||
                                  (own &&
                                      ['Suspend', 'Reject'].contains(action))
                              ? null
                              : () => change(action),
                          child: Text(action),
                        ),
                    ],
                  ),
                  _AdminPrivateNotes(kind: 'account', target: widget.uid),
                  if (busy) const LinearProgressIndicator(),
                ],
              );
            },
          ),
    ),
  );
}

class _AdminComplaintScreen extends StatefulWidget {
  const _AdminComplaintScreen({required this.requestId});
  final String requestId;
  @override
  State<_AdminComplaintScreen> createState() => _AdminComplaintScreenState();
}

class _AdminComplaintScreenState extends State<_AdminComplaintScreen> {
  String priority = 'normal';
  bool busy = false;
  late final review = FirebaseFirestore.instance
      .collection('complaintReviews')
      .doc(widget.requestId)
      .snapshots();
  Future<void> decide(String status) async {
    final reason = await _adminReason(context, 'Public decision / next step');
    if (reason == null || !mounted) return;
    setState(() => busy = true);
    try {
      await AdminService().reviewComplaint(
        widget.requestId,
        status: status,
        priority: priority,
        decision: reason,
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the decision.')),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Complaint review')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Review evidence, the invoice and both replies before deciding. Decisions are visible to both participants and do not process refunds.',
        ),
        OutlinedButton(
          onPressed: () =>
              push(context, DisputeScreen(requestId: widget.requestId)),
          child: const Text('View driver report, photos and provider response'),
        ),
        OutlinedButton(
          onPressed: () =>
              push(context, InvoiceScreen(requestId: widget.requestId)),
          child: const Text('View invoice and approval evidence'),
        ),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: review,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return const Text('Could not load admin review.');
            final data = snapshot.data?.data();
            return Column(
              children: [
                SummaryRow(
                  'Admin review',
                  data?['status'] as String? ?? 'not assigned',
                ),
                SummaryRow(
                  'Assigned admin',
                  data?['assignedTo'] as String? ?? 'none',
                ),
                SummaryRow(
                  'Priority',
                  data?['priority'] as String? ?? 'normal',
                ),
                if (data?['decision'] is String)
                  Text(data!['decision'] as String),
              ],
            );
          },
        ),
        DropdownButtonFormField<String>(
          initialValue: priority,
          decoration: const InputDecoration(
            labelText: 'Priority for next action',
          ),
          items: [
            for (final value in ['low', 'normal', 'high', 'urgent'])
              DropdownMenuItem(value: value, child: Text(value)),
          ],
          onChanged: busy ? null : (value) => setState(() => priority = value!),
        ),
        for (final status in ['under_review', 'resolved', 'dismissed'])
          OutlinedButton(
            onPressed: busy ? null : () => decide(status),
            child: Text(
              status == 'under_review'
                  ? 'Assign to me / Start review'
                  : status == 'resolved'
                  ? 'Record resolution'
                  : 'Dismiss with reason',
            ),
          ),
        _AdminPrivateNotes(kind: 'complaint', target: widget.requestId),
        if (busy) const LinearProgressIndicator(),
      ],
    ),
  );
}

class _AdminAuditScreen extends StatelessWidget {
  const _AdminAuditScreen({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Audit record')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        for (final key in [
          'kind',
          'target',
          'actor',
          'createdAt',
          'reason',
          'before',
          'after',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SelectableText('$key\n${data[key]}'),
          ),
      ],
    ),
  );
}

class AccountAccessGate extends StatelessWidget {
  const AccountAccessGate({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    initialData: FirebaseAuth.instance.currentUser,
    builder: (context, auth) {
      final user = auth.data;
      if (user == null) return child;
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('accountModeration')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.data?.data()?['status'] != 'suspended' &&
              snapshot.data?.data()?['verification'] != 'rejected')
            return child;
          return Material(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline),
                    const Text('App access suspended', style: RaText.title),
                    Text(
                      snapshot.data?.data()?['reason'] as String? ??
                          'Contact project support.',
                    ),
                    const Text('Contact project support to request a review.'),
                    TextButton(
                      onPressed: () => AuthService().signOut(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _AdminUserRow extends StatefulWidget {
  const _AdminUserRow({
    super.key,
    required this.uid,
    required this.data,
    required this.pendingOnly,
  });
  final String uid;
  final Map<String, dynamic> data;
  final bool pendingOnly;
  @override
  State<_AdminUserRow> createState() => _AdminUserRowState();
}

class _AdminUserRowState extends State<_AdminUserRow> {
  late final review = FirebaseFirestore.instance
      .collection('accountModeration')
      .doc(widget.uid)
      .snapshots();
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: review,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return const ListTile(title: Text('Could not load account review.'));
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final data = snapshot.data!.data() ?? {};
      final status = data['verification'] ?? 'pending';
      if (widget.pendingOnly && status != 'pending')
        return const SizedBox.shrink();
      return ListTile(
        title: Text(widget.data['displayName'] as String? ?? widget.uid),
        subtitle: Text(
          '${widget.data['email'] ?? ''}\n${widget.data['role']} / $status / ${data['status'] ?? 'active'}${data['flagged'] == true ? ' / Flagged' : ''}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => push(context, _AdminAccountScreen(uid: widget.uid)),
      );
    },
  );
}

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
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Job monitor')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: job,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text('Could not load job.'));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.data();
        if (data == null) return const Center(child: Text('Job not found.'));
        final updated = (data['updatedAt'] as Timestamp?)?.toDate();
        final active = [
          'accepted',
          'en_route',
          'arrived',
        ].contains(data['status']);
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(widget.requestId, style: RaText.title),
            SummaryRow('Status', data['status'] as String? ?? ''),
            SummaryRow('Driver', data['driverName'] as String? ?? ''),
            SummaryRow(
              'Provider',
              data['providerName'] as String? ?? 'Unassigned',
            ),
            SummaryRow('Vehicle', data['modelYear'] as String? ?? ''),
            SummaryRow('Problem', requestIssueLabel(data)),
            SummaryRow(
              'Location',
              data['locationLabel'] as String? ?? 'Not recorded',
            ),
            SummaryRow('Approved amount', 'Rs. ${data['estimatedCost'] ?? 0}'),
            if (updated != null)
              Text('Last recorded update: ${updated.toLocal()}'),
            if (active &&
                updated != null &&
                DateTime.now().difference(updated).inMinutes >= 60)
              const Text(
                'No recorded update for at least an hour. Review the situation; this alone does not establish a problem.',
              ),
            if (data['description'] is String)
              Text(data['description'] as String),
            if (data['status'] == 'completed')
              OutlinedButton(
                onPressed: () =>
                    push(context, InvoiceScreen(requestId: widget.requestId)),
                child: const Text('Review invoice and approvals'),
              ),
            const Text(
              'Monitoring is read-only. Contact the relevant participants through your agreed support process.',
            ),
          ],
        );
      },
    ),
  );
}

class _AdminPrivateNotes extends StatefulWidget {
  const _AdminPrivateNotes({required this.kind, required this.target});
  final String kind, target;
  @override
  State<_AdminPrivateNotes> createState() => _AdminPrivateNotesState();
}

class _AdminPrivateNotesState extends State<_AdminPrivateNotes> {
  bool busy = false;
  late final notes = FirebaseFirestore.instance
      .collection('adminNotes')
      .where('kind', isEqualTo: widget.kind)
      .where('target', isEqualTo: widget.target)
      .limit(50)
      .snapshots();
  Future<void> add() async {
    final text = await _adminReason(context, 'Private admin note');
    if (text == null || !mounted) return;
    setState(() => busy = true);
    try {
      await AdminService().addPrivateNote(widget.kind, widget.target, text);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save private note.')),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(),
      const Text('Private admin notes', style: RaText.title),
      const Text(
        'Visible only to admins; notes cannot be edited. Up to 50 loaded per case.',
      ),
      OutlinedButton(
        onPressed: busy ? null : add,
        child: const Text('Add private note'),
      ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: notes,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Text('Could not load private notes.');
          final entries = snapshot.data?.docs.toList() ?? [];
          entries.sort(
            (a, b) => (b.data()['createdAt'] as Timestamp).compareTo(
              a.data()['createdAt'] as Timestamp,
            ),
          );
          return Column(
            children: [
              for (final note in entries)
                ListTile(
                  title: Text(note.data()['text'] as String),
                  subtitle: Text(
                    '${note.data()['actor']} / ${(note.data()['createdAt'] as Timestamp).toDate().toLocal()}',
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}
