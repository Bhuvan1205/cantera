import 'package:flutter/foundation.dart';

/// Application-wide configuration constants.
///
/// Configuration values are injected at build time using `--dart-define`:
///
/// Development:
///   flutter run --dart-define=ENV=dev \
///               --dart-define=BACKEND_URL=http://127.0.0.1:8000
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

  static const String _explicitBackendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: '',
  );

  /// Base URL of the FastAPI backend deployed on Cloud Run or local.
  /// Automatically resolves between Web/Desktop (127.0.0.1) and Android Emulator (10.0.2.2).
  static String get backendBaseUrl {
    if (_explicitBackendUrl.isNotEmpty) {
      return _explicitBackendUrl;
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return 'http://127.0.0.1:8000';
    }
    return 'http://10.0.2.2:8000';
  }

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

  /// The physical sections available in the canteen.
  static const List<String> canteenSections = [
    'Bakery',
    'Mess',
    'Continental',
    'Beverages',
  ];
}

