import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/services/chat_inbox_controller.dart';

// Test-only stand-in for immutable Firestore snapshots.
// ignore: subtype_of_sealed_class
class TestDocument extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  TestDocument(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
}

class TestSnapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  TestSnapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

Future<void> flushStreams() => Future<void>.delayed(Duration.zero);
void main() {
  for (final provider in [true, false]) {
    test(
      '${provider ? 'provider' : 'driver'} receives live unread chats on completed jobs and clears them on reading',
      () async {
        final jobs =
            StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
        final messages =
            StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
        final inbox = ChatInboxController(
          isProvider: provider,
          userId: 'self',
          requests: jobs.stream,
          messages: (_) => messages.stream,
        );
        final job = <String, dynamic>{
          'providerId': provider ? 'self' : 'other',
          'driverId': provider ? 'other' : 'self',
          'status': 'completed',
        };
        jobs.add(TestSnapshot([TestDocument('completed-job', job)]));
        await flushStreams();
        expect(messages.hasListener, isTrue);
        final received = {
          'senderId': 'other',
          'text': 'Question after repair',
          'createdAt': Timestamp(10, 0),
        };
        messages.add(TestSnapshot([TestDocument('message', received)]));
        await flushStreams();
        expect(inbox.unread, 1);
        expect(inbox.threadIds, ['completed-job']);
        jobs.add(
          TestSnapshot([
            TestDocument('completed-job', {
              ...job,
              provider ? 'providerMessagesSeenAt' : 'driverMessagesSeenAt':
                  Timestamp(20, 0),
            }),
          ]),
        );
        await flushStreams();
        expect(inbox.unread, 0);
        messages.add(
          TestSnapshot([
            TestDocument('message', received),
            TestDocument('new-photo', {
              'senderId': 'other',
              'text': '',
              'imageData': 'photo',
              'createdAt': Timestamp(30, 0),
            }),
            TestDocument('reply', {
              'senderId': 'self',
              'text': 'Reply',
              'createdAt': Timestamp(40, 0),
            }),
          ]),
        );
        await flushStreams();
        expect(inbox.unread, 1);
        jobs.add(TestSnapshot([]));
        await flushStreams();
        expect(inbox.unread, 0);
        expect(inbox.threadIds, isEmpty);
        expect(messages.hasListener, isFalse);
        inbox.dispose();
        await jobs.close();
        await messages.close();
      },
    );
  }
  test('messages at the read timestamp and own messages are not unread', () {
    expect(
      countUnreadChatMessages(
        [
          {'senderId': 'other', 'createdAt': Timestamp(10, 0)},
          {'senderId': 'self', 'createdAt': Timestamp(30, 0)},
          {'senderId': 'other', 'createdAt': Timestamp(20, 0)},
        ],
        'self',
        Timestamp(10, 0),
      ),
      1,
    );
  });
}
