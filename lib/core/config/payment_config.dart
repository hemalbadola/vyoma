import 'app_config.dart';

/// Razorpay configuration (no secrets in app binary).
class PaymentConfig {
  PaymentConfig._();

  static String get apiBase => AppConfig.paymentApiBase;

  static const razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: '',
  );

  static bool get isConfigured => razorpayKeyId.isNotEmpty;
}
