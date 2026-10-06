part of '../../screens.dart';

class _AdminRecords extends StatefulWidget {
  const _AdminRecords({super.key, required this.kind});
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
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        leading: CircleAvatar(
                          child: Icon(
                            widget.kind == 'jobs'
                                ? Icons.route_outlined
                                : widget.kind == 'complaints'
                                ? Icons.support_agent
                                : Icons.history,
                          ),
                        ),
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
                        trailing: Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (widget.kind != 'audit')
                              _AdminStatusBadge(
                                status: (doc.data()['status'] ?? 'open')
                                    .toString(),
                              ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
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
                    ),
                if (docs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No matching records. Try another search or filter.',
                      ),
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
