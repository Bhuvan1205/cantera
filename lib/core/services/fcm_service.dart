import 'dart:async';
import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  StreamSubscription<String>? _tokenRefreshSub;
  bool _initialized = false;

  /// Initializes FCM token registration and refresh listening.
  /// Should be called after successful authentication.
  Future<void> initialize() async {
    if (_initialized) return;
    
    // Graceful no-op for web since it requires a VAPID key which isn't configured here
    if (kIsWeb) {
      log('FCM not supported on web without VAPID key, skipping FCM initialization.');
      return;
    }

    try {
      // Request permissions (important for iOS, no-op/auto-granted on Android 12-)
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      log('FCM permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized || 
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // Get initial token
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _registerTokenWithBackend(token);
        }

        // Listen for token refreshes
        _tokenRefreshSub?.cancel();
        _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
          _registerTokenWithBackend(newToken);
        });

        _initialized = true;
      }
    } catch (e) {
      log('Failed to initialize FCM: $e');
    }
  }

  /// Sends the token to the FastAPI backend.
  /// The backend uses the authenticated user's uid from the Authorization header.
  Future<void> _registerTokenWithBackend(String token) async {
    try {
      await ApiClient.instance.post(
        '/api/users/fcm-token',
        body: {'token': token},
      );
      log('Successfully registered FCM token with backend.');
    } catch (e) {
      log('Failed to register FCM token with backend: $e');
    }
  }

  /// Deletes the token from the FastAPI backend (called before sign out).
  Future<void> deleteTokenFromBackend(String token) async {
    try {
      await ApiClient.instance.delete(
        '/api/users/fcm-token',
        body: {'token': token},
      );
      log('Successfully deleted FCM token from backend.');
    } catch (e) {
      log('Failed to delete FCM token from backend (or token not found): $e');
    }
  }

  /// Cleans up subscriptions on sign out.
  void dispose() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _initialized = false;
  }
}
