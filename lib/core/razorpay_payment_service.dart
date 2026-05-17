import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'config/payment_config.dart';
import 'config/razorpay_checkout_config.dart';
import 'models/subscription_plan.dart';

class RazorpayPaymentService {
  Razorpay? _razorpay;
  void Function(String message)? _onFailure;
  Future<void> Function(Map<String, dynamic> response)? _onSuccess;

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }

  Future<Map<String, dynamic>> createOrder(SubscriptionPlan plan) async {
    final user = FirebaseAuth.instance.currentUser;
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (user != null) {
      headers['Authorization'] = 'Bearer ${await user.getIdToken()}';
    }

    final res = await http.post(
      Uri.parse('${PaymentConfig.apiBase}/create-order'),
      headers: headers,
      body: jsonEncode({
        'planId': plan.id,
        'receipt': 'vyoma_${plan.id}_${DateTime.now().millisecondsSinceEpoch}',
        if (user != null) 'uid': user.uid,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>?;
      throw Exception(body?['error'] ?? 'Failed to create order (${res.statusCode})');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyPayment(Map<String, dynamic> response) async {
    final user = FirebaseAuth.instance.currentUser;
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (user != null) {
      headers['Authorization'] = 'Bearer ${await user.getIdToken()}';
    }

    final res = await http.post(
      Uri.parse('${PaymentConfig.apiBase}/verify-payment'),
      headers: headers,
      body: jsonEncode({
        'razorpay_order_id': response['razorpay_order_id'],
        'razorpay_payment_id': response['razorpay_payment_id'],
        'razorpay_signature': response['razorpay_signature'],
      }),
    );

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['error'] ?? 'Payment verification failed');
    }
    return body;
  }

  Future<void> startCheckout({
    required SubscriptionPlan plan,
    required void Function() onDismissed,
    required void Function(String message) onFailure,
    required Future<void> Function() onVerified,
  }) async {
    if (!PaymentConfig.isConfigured) {
      throw Exception('Razorpay key not configured. Pass --dart-define=RAZORPAY_KEY_ID=...');
    }

    _onFailure = onFailure;
    _onSuccess = (_) async => onVerified();

    final order = await createOrder(plan);
    _razorpay?.clear();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _handleError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    final options = <String, dynamic>{
      'key': order['key_id'] ?? PaymentConfig.razorpayKeyId,
      'amount': order['amount'],
      'currency': order['currency'] ?? 'INR',
      'name': 'VYOMA',
      'description': '${plan.name} subscription',
      'order_id': order['order_id'],
      'prefill': {
        'email': FirebaseAuth.instance.currentUser?.email,
        'contact': FirebaseAuth.instance.currentUser?.phoneNumber,
      },
      ...RazorpayCheckoutConfig.checkoutOptions,
    };

    _razorpay!.open(options);
  }

  void _handleSuccess(PaymentSuccessResponse response) async {
    try {
      final payload = {
        'razorpay_order_id': response.orderId,
        'razorpay_payment_id': response.paymentId,
        'razorpay_signature': response.signature,
      };
      await verifyPayment(payload);
      await _onSuccess?.call(payload);
    } catch (e) {
      debugPrint('RAZORPAY_DEBUG: verify failed: $e');
      _onFailure?.call(e.toString());
    }
  }

  void _handleError(PaymentFailureResponse response) {
    _onFailure?.call(response.message ?? 'Payment failed');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('RAZORPAY_DEBUG: external wallet ${response.walletName}');
  }
}
