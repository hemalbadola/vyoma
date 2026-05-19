import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'config/app_config.dart';

class CouponService {
  Future<Map<String, dynamic>> redeem(String code) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Sign in to redeem a coupon');
    }

    final token = await user.getIdToken();
    final res = await http.post(
      Uri.parse('${AppConfig.paymentApiBase}/redeem-coupon'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'code': code.trim()}),
    );

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['error'] ?? 'Could not redeem coupon');
    }

    debugPrint('COUPON_DEBUG: redeemed ${body['code']} until ${body['subscriptionExpiresAt']}');
    await user.getIdToken(true);
    return body;
  }
}
