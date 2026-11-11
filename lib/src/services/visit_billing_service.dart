import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class VisitBillingService {
  static const endpoint = String.fromEnvironment(
    'VISIT_BILLING_API_URL',
    defaultValue: 'https://vehiclebreakdownapp.vercel.app/api/visit-billing',
  );
  Future<Map<String, dynamic>> send(
    String action,
    Map<String, dynamic> values,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in again.');
    final token = await user.getIdToken();
    final response = await http
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
      throw StateError('Billing is temporarily unavailable. Please retry.');
    }
    if (response.statusCode != 200)
      throw StateError(
        data['message']?.toString() ?? 'Unable to update billing.',
      );
    return data;
  }
}
