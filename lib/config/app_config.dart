import 'package:flutter/foundation.dart';

/// Application-wide configuration constants.
///
/// Backend URL configuration:
///   Development (Android emulator) : `http://10.0.2.2:8000`
///   Development (physical device)  : `http://<your-machine-LAN-IP>:8000`
///   Production                     : `https://<your-deployed-backend-url>`
///
/// Update [backendBaseUrl] here and it applies to all backend calls in the app.
class AppConfig {
  AppConfig._(); // Prevent instantiation

  /// Base URL of the FastAPI backend.
  /// Change this single constant to switch environments.
  static String get backendBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    } else {
      return 'http://10.0.2.2:8000';
    }
  }

  /// The physical sections available in the canteen.
  static const List<String> canteenSections = [
    'Bakery',
    'Mess',
    'Continental',
    'Beverages',
  ];
}
