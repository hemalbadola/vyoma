import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/coupon_service.dart';
import '../../core/models/subscription_plan.dart';
import '../../core/razorpay_payment_service.dart';
import '../widgets/glass_card.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _payments = RazorpayPaymentService();
  final _coupons = CouponService();
  final _couponController = TextEditingController();
  List<SubscriptionPlan> _plans = [];
  bool _loading = true;
  String? _error;
  String? _status;
  bool _paying = false;
  bool _redeemingCoupon = false;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  @override
  void dispose() {
    _couponController.dispose();
    _payments.dispose();
    super.dispose();
  }

  Future<void> _redeemCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter a coupon code');
      return;
    }
    setState(() {
      _redeemingCoupon = true;
      _error = null;
      _status = null;
    });
    try {
      final result = await _coupons.redeem(code);
      if (!mounted) return;
      setState(() {
        _redeemingCoupon = false;
        _status =
            'Coupon applied — ${result['durationDays']} days free (until ${result['subscriptionExpiresAt']}).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _redeemingCoupon = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadPlans() async {
    try {
      final raw = await rootBundle.loadString('assets/config/subscription_plans.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final plans = (json['plans'] as List)
          .map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load plans: $e';
        _loading = false;
      });
    }
  }

  Future<void> _pay(SubscriptionPlan plan) async {
    setState(() {
      _paying = true;
      _error = null;
      _status = null;
    });

    try {
      await _payments.startCheckout(
        plan: plan,
        onDismissed: () {
          if (mounted) {
            setState(() {
              _paying = false;
              _status = 'Payment cancelled';
            });
          }
        },
        onFailure: (message) {
          if (mounted) {
            setState(() {
              _paying = false;
              _error = message;
            });
          }
        },
        onVerified: () async {
          if (mounted) {
            setState(() {
              _paying = false;
              _status = '${plan.name} active — synced across web & app.';
            });
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _paying = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060B19),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'SUBSCRIPTION',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Same plans as vyomai.app — one subscription, synced to your account.',
                  style: GoogleFonts.outfit(color: Colors.white60, height: 1.45),
                ),
                const SizedBox(height: 16),
                if (_status != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_status!, style: const TextStyle(color: Color(0xFF86EFAC))),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: const TextStyle(color: Color(0xFFFCA5A5))),
                  ),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Have a coupon?',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _couponController,
                        style: const TextStyle(color: Colors.white),
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'VYOMA-VIP-1MONTH',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _redeemingCoupon ? null : _redeemCoupon,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD4AF37),
                            side: const BorderSide(color: Color(0xFFD4AF37)),
                          ),
                          child: Text(_redeemingCoupon ? 'Applying…' : 'Redeem 1-month trial'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ..._plans.map((plan) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.name,
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 26,
                                color: const Color(0xFFE8D3A8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              plan.priceLabel,
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFC9A84C),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _paying ? null : () => _pay(plan),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD4AF37),
                                  foregroundColor: const Color(0xFF060B19),
                                ),
                                child: Text(_paying ? 'Processing…' : plan.cta),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
              ],
            ),
    );
  }
}
