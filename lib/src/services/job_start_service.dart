import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class JobStartService {
  // Enable only after the endpoint and matching security rules are deployed.
  static const enabled = bool.fromEnvironment('JOB_START_CODE_ENABLED');
  static const endpoint = String.fromEnvironment(
    'JOB_START_CODE_API_URL',
    defaultValue: 'https://vehiclebreakdownapp.vercel.app/api/job-start-code',
  );
  Future<Map<String, dynamic>> send(
    String requestId,
    String action, {
    String? code,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in again to continue.');
    final token = await user.getIdToken();
    final result = await http
        .post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'requestId': requestId,
            'action': action,
            if (code != null) 'code': code,
          }),
        )
        .timeout(const Duration(seconds: 20));
    Map<String, dynamic> data;
    try {
      data = jsonDecode(result.body) as Map<String, dynamic>;
    } catch (_) {
      throw StateError('Job start verification is temporarily unavailable.');
    }
    if (result.statusCode != 200)
      throw StateError(
        data['message']?.toString() ?? 'Unable to verify job start.',
      );
    return data;
  }
}
