import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/request_draft.dart';

class RequestDraftStore {
  RequestDraftStore({SharedPreferences? preferences, String? ownerId})
    : _preferences = preferences,
      _ownerId =
          ownerId ??
          (Firebase.apps.isEmpty
              ? null
              : FirebaseAuth.instance.currentUser?.uid) ??
          'guest';

  final String _ownerId;

  String get _draftKey => 'roadassist_driver_request_draft_v2_$_ownerId';
  String get _updatedAtKey =>
      'roadassist_driver_request_draft_updated_at_v2_$_ownerId';
  String get _pendingSubmissionKey =>
      'roadassist_driver_request_pending_submission_v2_$_ownerId';

  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<void> save(RequestDraft draft) async {
    final preferences = await _prefs;
    await preferences.setString(_draftKey, jsonEncode(draft.toJson()));
    await preferences.setString(
      _updatedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<RequestDraft?> load() async {
    final encoded = (await _prefs).getString(_draftKey);
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return RequestDraft.fromJson(
        Map<String, dynamic>.from(jsonDecode(encoded) as Map),
      );
    } on FormatException {
      await clear();
      return null;
    } on TypeError {
      await clear();
      return null;
    }
  }

  Future<DateTime?> lastUpdated() async {
    final value = (await _prefs).getString(_updatedAtKey);
    return value == null ? null : DateTime.tryParse(value)?.toLocal();
  }

  Future<void> clear() async {
    final preferences = await _prefs;
    await preferences.remove(_draftKey);
    await preferences.remove(_updatedAtKey);
    await preferences.remove(_pendingSubmissionKey);
  }

  Future<void> setPendingSubmission(bool pending) async {
    final preferences = await _prefs;
    await preferences.setBool(_pendingSubmissionKey, pending);
  }

  Future<bool> hasPendingSubmission() async =>
      (await _prefs).getBool(_pendingSubmissionKey) ?? false;
}
