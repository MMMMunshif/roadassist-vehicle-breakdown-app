import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class GuestAssistanceService {
  GuestAssistanceService({http.Client? client})
    : client = client ?? http.Client();
  final http.Client client;
  static const endpoint = String.fromEnvironment(
    'GUEST_ASSISTANCE_API_URL',
    defaultValue: 'https://vehiclebreakdownapp.vercel.app/api/guest-assistance',
  );
  static bool get hasGuestIdentity =>
      Firebase.apps.isNotEmpty &&
      FirebaseAuth.instance.currentUser != null &&
      FirebaseAuth.instance.currentUser?.email == null;
  Future<bool> available() async {
    final response = await client
        .get(Uri.parse(endpoint))
        .timeout(const Duration(seconds: 12));
    return response.statusCode == 200 &&
        (jsonDecode(response.body) as Map)['enabled'] == true;
  }

  Future<Map<String, dynamic>> send(
    String action, [
    Map<String, dynamic> values = const {},
  ]) async {
    final user = FirebaseAuth.instance.currentUser;
    if (!hasGuestIdentity || user == null)
      throw StateError('Open your guest session first.');
    final token = await user.getIdToken();
    final response = await client
        .post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'action': action, ...values}),
        )
        .timeout(const Duration(seconds: 25));
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw StateError(
        'Guest assistance is unavailable. Retry when connected.',
      );
    }
    if (response.statusCode != 200)
      throw StateError(
        data['message']?.toString() ?? 'Unable to update your request.',
      );
    return data;
  }

  void dispose() => client.close();
}

String guestPhoneError(FirebaseAuthException error) => switch (error.code) {
  'operation-not-allowed' =>
    'Guest access needs Anonymous sign-in enabled. Emergency help is still available.',
  'too-many-requests' => 'Too many attempts. Please wait before trying again.',
  'network-request-failed' => 'Reconnect before opening guest access.',
  _ => 'Unable to open guest access. Retry or use Emergency help.',
};
