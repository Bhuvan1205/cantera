import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../core/utils/idempotency.dart';

/// Central service for all order operations.
///
/// Under ADR-001 (Backend-First Architecture), all mutations execute
/// exclusively via the FastAPI backend on Cloud Run.
class OrderService {
  // ──────────────────────────────────────────────────────────────────────────
  // Server-Side Atomic Checkout (P-05, P-06)
  // ──────────────────────────────────────────────────────────────────────────

  /// Orchestrates order placement via FastAPI backend with atomic stock reservation,
  /// wallet debit, and atomic counter token allocation.
  static Future<String> placeOrderViaBackend({
    required Map<String, Map<String, dynamic>> cart,
    required String userId,
    String? userName,
    String paymentMethod = 'wallet',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User is not authenticated.');

    final idToken = await user.getIdToken();
    final uri = Uri.parse('${AppConfig.backendBaseUrl}/api/orders/checkout');

    final itemsPayload = cart.entries.map((e) => {
      'menu_item_id': e.key,
      'quantity': e.value['quantity'] as int,
    }).toList();

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
        'Idempotency-Key': IdempotencyUtils.generateKey(),
      },
      body: jsonEncode({
        'items': itemsPayload,
        'payment_method': paymentMethod,
        'user_name': userName ?? user.displayName,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final detail = body?['detail'] as String? ?? 'Order placement failed.';
      throw Exception(detail);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['order_id'] as String;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // QR Scan Handler & OTP Verification
  // ──────────────────────────────────────────────────────────────────────────

  /// Calls FastAPI backend to process QR scan securely with server authorization.
  static Future<Map<String, dynamic>> handleQrScanViaBackend(String scannedValue) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User is not authenticated.');

    final idToken = await user.getIdToken();
    final uri = Uri.parse('${AppConfig.backendBaseUrl}/api/orders/scan-qr');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'qr_payload': scannedValue}),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final detail = body?['detail'] as String? ?? 'QR scan failed.';
      throw Exception(detail);
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Convenience wrapper for QR scans returning the backend status message.
  static Future<String> handleQrScan(String scannedValue) async {
    final res = await handleQrScanViaBackend(scannedValue);
    return res['message'] as String? ?? 'Scan processed successfully.';
  }

  /// Calls FastAPI backend to verify mess counter student OTP.
  static Future<void> verifyOtpViaBackend({
    required String orderId,
    required String counter,
    required String otp,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User is not authenticated.');

    final idToken = await user.getIdToken();
    final uri = Uri.parse('${AppConfig.backendBaseUrl}/api/orders/verify-otp');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'order_id': orderId,
        'counter': counter,
        'otp': otp,
      }),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final detail = body?['detail'] as String? ?? 'OTP verification failed.';
      throw Exception(detail);
    }
  }

  /// Verifies student OTP via FastAPI backend with atomic queue advancement.
  static Future<void> verifyMessOtp({
    required String orderId,
    required String tokenId,
    required String otp,
  }) async {
    await verifyOtpViaBackend(
      orderId: orderId,
      counter: 'mess',
      otp: otp,
    );
  }
}
