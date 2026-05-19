/// Remote config URLs for Vyoma client apps.
class AppConfig {
  AppConfig._();

  static const releaseManifestUrl = String.fromEnvironment(
    'RELEASE_MANIFEST_URL',
    defaultValue: 'https://vyomai.app/releases.json',
  );

  /// Primary update destination for all platforms.
  static const updateWebsiteUrl = 'https://vyomai.app';

  static const paymentApiBase = String.fromEnvironment(
    'PAYMENT_API_BASE',
    defaultValue: 'https://vyoma-api-backend-9629c91b8aad.herokuapp.com/api',
  );
}
