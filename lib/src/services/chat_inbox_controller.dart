import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'request_service.dart';

int countUnreadChatMessages(
  Iterable<Map<String, dynamic>> messages,
  String uid,
  Timestamp? seenAt,
) => messages.where((message) {
  if (message['senderId'] == uid) return false;
  final created = message['createdAt'] as Timestamp?;
  return seenAt == null || created == null || created.compareTo(seenAt) > 0;
}).length;

class ChatInboxController extends ChangeNotifier {
  ChatInboxController({
    required this.isProvider,
    String? userId,
    Stream<QuerySnapshot<Map<String, dynamic>>>? requests,
    Stream<QuerySnapshot<Map<String, dynamic>>> Function(String)? messages,
  }) {
    uid = userId ?? FirebaseAuth.instance.currentUser!.uid;
    final service = requests == null || messages == null
        ? RequestService()
        : null;
    _messages = messages ?? service!.watchMessages;
    _jobs =
        (requests ??
                (isProvider
                    ? service!.watchProviderRequests()
                    : service!.watchDriverRequests()))
            .listen(_updateJobs, onError: _onError);
  }
  final bool isProvider;
  late final String uid;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> Function(String)
  _messages;
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> _jobs;
  final jobs = <String, Map<String, dynamic>>{};
  final conversations = <String, List<Map<String, dynamic>>>{};
  final _listeners =
      <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
  final _failed = <String>{};
  bool _closed = false;
  bool loading = true;
  bool requestsFailed = false;
  bool get hasError => requestsFailed || _failed.isNotEmpty;
  int unreadFor(String id) => countUnreadChatMessages(
    conversations[id] ?? [],
    uid,
    jobs[id]?[isProvider ? 'providerMessagesSeenAt' : 'driverMessagesSeenAt']
        as Timestamp?,
  );
  int get unread => jobs.keys.fold(0, (total, id) => total + unreadFor(id));
  List<String> get threadIds =>
      conversations.keys
          .where((id) => jobs.containsKey(id) && conversations[id]!.isNotEmpty)
          .toList()
        ..sort((a, b) {
          final aTime = conversations[a]!.last['createdAt'] as Timestamp?;
          final bTime = conversations[b]!.last['createdAt'] as Timestamp?;
          return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
            aTime?.millisecondsSinceEpoch ?? 0,
          );
        });
  void _onError(Object error) {
    if (_closed) return;
    requestsFailed = true;
    loading = false;
    notifyListeners();
  }

  void _updateJobs(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (_closed) return;
    requestsFailed = false;
    final next = {
      for (final doc in snapshot.docs)
        if ((doc.data()['providerId'] as String? ?? '').isNotEmpty)
          doc.id: doc.data(),
    };
    for (final id in _listeners.keys.toList()) {
      if (!next.containsKey(id)) {
        _listeners.remove(id)?.cancel();
        conversations.remove(id);
        _failed.remove(id);
      }
    }
    jobs
      ..clear()
      ..addAll(next);
    for (final id in jobs.keys) {
      if (_listeners.containsKey(id)) continue;
      _listeners[id] = _messages(id).listen(
        (snapshot) {
          if (_closed || !jobs.containsKey(id)) return;
          _failed.remove(id);
          conversations[id] = snapshot.docs.map((d) => d.data()).toList();
          notifyListeners();
        },
        onError: (Object error) {
          if (_closed) return;
          _failed.add(id);
          notifyListeners();
        },
      );
    }
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    _jobs.cancel();
    for (final listener in _listeners.values) {
      listener.cancel();
    }
    super.dispose();
  }
}
