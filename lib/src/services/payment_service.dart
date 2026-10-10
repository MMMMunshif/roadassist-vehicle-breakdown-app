import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class PaymentCheckout {
  const PaymentCheckout({required this.paymentId, required this.checkoutUrl});

  final String paymentId;
  final String checkoutUrl;
}

class PaymentService {
  PaymentService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _endpoint(String path) {
    const configured = String.fromEnvironment('PAYMENT_API_BASE_URL');
    if (configured.isNotEmpty) {
      return Uri.parse(configured).resolve(path);
    }
    return Uri.base.resolve(path);
  }

  Future<PaymentCheckout> createCheckout(String requestId) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    if (user == null || token == null) {
      throw StateError('Sign in again before starting payment.');
    }

    final response = await _client.post(
      _endpoint('/api/create-payment-order'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'requestId': requestId}),
    );

    Map<String, dynamic> body = const {};
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      // The server response is handled below with a safe generic message.
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        body['message'] as String? ?? 'Unable to start secure payment.',
      );
    }
    final paymentId = body['paymentId'] as String?;
    final checkoutUrl = body['checkoutUrl'] as String?;
    if (paymentId == null || checkoutUrl == null) {
      throw StateError('Payment gateway configuration is incomplete.');
    }
    return PaymentCheckout(paymentId: paymentId, checkoutUrl: checkoutUrl);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPayment(
    String requestId,
    String paymentId,
  ) =>
      FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .collection('payments')
          .doc(paymentId)
          .snapshots();
}
