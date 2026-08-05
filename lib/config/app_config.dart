/// Application-wide configuration constants.
///
/// Configuration values are injected at build time using `--dart-define`:
///
/// Development:
///   flutter run --dart-define=ENV=dev \
///               --dart-define=BACKEND_URL=http://10.0.2.2:8000
///
/// Staging:
///   flutter run --dart-define=ENV=staging \
///               --dart-define=BACKEND_URL=https://canteen-api-staging-xxxx.a.run.app \
///               --dart-define=RAZORPAY_KEY_ID=rzp_test_STAGING_KEY
///
/// Production:
///   flutter build apk --dart-define=ENV=prod \
///                     --dart-define=BACKEND_URL=https://api.canteen.yourdomain.com \
///                     --dart-define=RAZORPAY_KEY_ID=rzp_live_PROD_KEY
class AppConfig {
  AppConfig._(); // Prevent instantiation

  /// Environment name: 'dev', 'staging', or 'prod'.
  static const String env = String.fromEnvironment(
    'ENV',
    defaultValue: 'dev',
  );

  /// Base URL of the FastAPI backend deployed on Cloud Run or local.
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// Public Razorpay Key ID for client-side checkout opening.
  /// (Secret key is strictly stored server-side in Secret Manager).
  static const String razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'rzp_test_PLACEHOLDER',
  );

  /// Environment helpers
  static bool get isProduction => env == 'prod';
  static bool get isStaging => env == 'staging';
  static bool get isDev => env == 'dev';
}

