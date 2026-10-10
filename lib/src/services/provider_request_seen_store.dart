import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProviderRequestSeenStore {
  static const _maxRememberedRequests = 500;
  static final revision = ValueNotifier<int>(0);

  String _key(String userId) => 'roadassist_provider_seen_requests_v1_$userId';

  Future<Set<String>> load(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(_key(userId)) ?? const <String>[])
        .toSet();
  }

  Future<void> markSeen(String userId, Iterable<String> requestIds) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _key(userId);
    final seen = preferences.getStringList(key) ?? <String>[];
    final updated = <String>{...seen, ...requestIds};

    if (updated.length == seen.length) return;

    final bounded = updated.length > _maxRememberedRequests
        ? updated.skip(updated.length - _maxRememberedRequests).toList()
        : updated.toList();
    if (!await preferences.setStringList(key, bounded)) {
      throw StateError('Unable to save viewed requests on this device.');
    }

    revision.value++;
  }
}
