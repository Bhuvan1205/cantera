import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../config/app_config.dart';
import '../../core/services/api_client.dart';
import '../models/pending_deposit_model.dart';
import '../models/refund_request_model.dart';
import '../models/wallet_model.dart';
import '../models/wallet_transaction_model.dart';
import '../repositories/firestore_wallet_repository.dart';

/// Which payment gateway to use for a deposit.
enum PaymentGateway {
  razorpay, // Production Razorpay gateway
  mock,     // Simulated gateway for testing (no real money)
}

/// Which payment method the user selects when placing an order.
enum OrderPaymentMethod {
  wallet,        // Deduct from wallet credits
  directPayment, // UPI / Card / other (not handled by wallet module)
}

/// Central service for all wallet operations.
///
/// Under ADR-001 (Backend-First Architecture), all mutations execute
/// exclusively via the FastAPI backend on Cloud Run.
/// Real-time reads and streams are served via [FirestoreWalletRepository].
class WalletService {
  WalletService._(); // Prevent instantiation

  static final _repo = FirestoreWalletRepository();

  // ── Deposit constraints ─────────────────────────────────────────────────
  static const double minDepositAmount = 20.0;
  static const double maxDepositAmount = 500.0;

  // ── Wallet reads ────────────────────────────────────────────────────────

  /// Live stream of the authenticated user's wallet.
  static Stream<WalletModel?> watchWallet(String userId) =>
      _repo.watchWallet(userId);

  /// One-time fetch of the wallet balance.
  static Future<WalletModel?> getWallet(String userId) =>
      _repo.getWallet(userId);

  /// Live stream of the user's wallet transactions (50 most recent).
  static Stream<List<WalletTransactionModel>> watchTransactions(
    String userId, {
    int limit = 50,
  }) =>
      _repo.watchTransactions(userId, limit: limit);

  /// Live stream of the user's own pending deposits.
  static Stream<List<PendingDepositModel>> watchUserPendingDeposits(
    String userId,
  ) =>
      _repo.watchUserPendingDeposits(userId);

  // ── Deposit amount validation ────────────────────────────────────────────

  /// Validates the deposit amount against business rules.
  /// Returns null if valid; returns an error string if invalid.
  static String? validateDepositAmount(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Please enter an amount.';
    final value = double.tryParse(trimmed);
    if (value == null) return 'Enter a valid number.';
    if (value < minDepositAmount) {
      return 'Minimum deposit is ₹${minDepositAmount.toStringAsFixed(0)}.';
    }
    if (value > maxDepositAmount) {
      return 'Maximum deposit is ₹${maxDepositAmount.toStringAsFixed(0)}.';
    }
    return null;
  }

  // ── Razorpay payment flow ────────────────────────────────────────────────

  /// Requests the backend to compute the deposit order and create a Razorpay order.
  /// Returns a map with razorpay_order_id, amount_paise, and deposit_id.
  static Future<Map<String, dynamic>> createDepositOrder(double amount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User is not authenticated.');

    final idToken = await user.getIdToken();
    final uri = Uri.parse('${AppConfig.backendBaseUrl}/api/wallet/orders/deposit');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'amount': amount}),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final detail = body?['detail'] as String? ?? 'Failed to initialize deposit order.';
      throw Exception(detail);
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Builds the Razorpay checkout options map.
  ///
  /// The [orderId] is the server-authorized Razorpay order ID.
  static Map<String, dynamic> buildRazorpayOptions({
    required double amount,
    required String userId,
    String? orderId,
    required void Function(PaymentSuccessResponse) onSuccess,
    required void Function(PaymentFailureResponse) onError,
    required void Function(ExternalWalletResponse) onExternalWallet,
    required Razorpay razorpayInstance,
  }) {
    final user = FirebaseAuth.instance.currentUser;

    razorpayInstance.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
    razorpayInstance.on(Razorpay.EVENT_PAYMENT_ERROR, onError);
    razorpayInstance.on(Razorpay.EVENT_EXTERNAL_WALLET, onExternalWallet);

    final options = <String, dynamic>{
      'key': AppConfig.razorpayKeyId,
      'amount': (amount * 100).toInt(), // Razorpay expects paise
      'name': 'Cantora',
      'description': 'Wallet Top-up',
      'prefill': {
        'contact': user?.phoneNumber ?? '',
        'email': user?.email ?? '',
        'name': user?.displayName ?? '',
      },
      'theme': {'color': '#0F382B'}, // AppColors.primary
    };

    if (orderId != null && orderId.isNotEmpty) {
      options['order_id'] = orderId;
    }

    return options;
  }

  // ── Backend payment verification ─────────────────────────────────────────

  /// Sends the deposit to the backend for payment verification and wallet credit.
  ///
  /// Flow:
  ///   1. Gets the current user's Firebase ID token.
  ///   2. POSTs {deposit_id} to [AppConfig.backendBaseUrl]/api/wallet/deposits/verify.
  ///   3. Backend verifies signature (Razorpay: HMAC-SHA256 / Mock: skipped),
  ///      then atomically credits the wallet via Firebase Admin SDK.
  ///
  /// Throws an [Exception] with a user-readable message on failure.
  static Future<void> verifyDeposit(String depositId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User is not authenticated.');

    final idToken = await user.getIdToken();
    final uri = Uri.parse('${AppConfig.backendBaseUrl}/api/wallet/deposits/verify');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'deposit_id': depositId}),
    );

    if (response.statusCode == 200) return; // Success or idempotent already_approved.

    // Parse backend error detail if available.
    String message = 'Payment verification failed. Contact support.';
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = body['detail'] as String?;
      if (detail != null && detail.isNotEmpty) message = detail;
    } catch (_) {}
    throw Exception(message);
  }

  // ── Refund request ───────────────────────────────────────────────────────

  /// Creates a refund request for an order still in 'placed' status via backend.
  static Future<void> requestRefund({
    required String userId,
    required String orderId,
    required double amount,
    String? reason,
  }) async {
    await ApiClient.instance.post('/api/wallet/refunds/request', body: {
      'order_id': orderId,
      'reason': reason,
    });
  }

  // ── Admin operations ─────────────────────────────────────────────────────

  /// Admin: approve a pending deposit and credit the wallet.
  static Future<void> approveDeposit(
    String depositId,
    String adminUid,
  ) async {
    await ApiClient.instance.post('/api/wallet/deposits/$depositId/review', body: {
      'action': 'approve',
    });
  }

  /// Admin: reject a pending deposit without crediting the wallet.
  static Future<void> rejectDeposit(
    String depositId,
    String adminUid,
    String reason,
  ) async {
    await ApiClient.instance.post('/api/wallet/deposits/$depositId/review', body: {
      'action': 'reject',
      'reason': reason,
    });
  }

  /// Admin: approve a refund request and credit the wallet.
  static Future<void> approveRefund(
    String requestId,
    String adminUid,
  ) async {
    await ApiClient.instance.patch('/api/wallet/refunds/$requestId', body: {
      'status': 'approved',
    });
  }

  /// Admin: move a refund request to under review status.
  static Future<void> reviewRefund(
    String requestId,
    String adminUid,
  ) async {
    await ApiClient.instance.patch('/api/wallet/refunds/$requestId', body: {
      'status': 'refund_under_review',
    });
  }

  /// Admin: reject a refund request.
  static Future<void> rejectRefund(
    String requestId,
    String adminUid,
    String reason,
  ) async {
    await ApiClient.instance.patch('/api/wallet/refunds/$requestId', body: {
      'status': 'rejected',
      'reason': reason,
    });
  }

  /// Admin: live stream of all pending deposits.
  static Stream<List<PendingDepositModel>> watchAllPendingDeposits() =>
      _repo.watchAllPendingDeposits();

  /// Admin: live stream of all pending refund requests.
  static Stream<List<RefundRequestModel>> watchAllRefundRequests() =>
      _repo.watchAllRefundRequests();

  /// Admin: create a manual wallet adjustment.
  static Future<void> createAdjustment({
    required String userId,
    required double amount,
    required String description,
    required String adminUid,
  }) async {
    await ApiClient.instance.post('/api/wallet/adjustments', body: {
      'user_uid': userId,
      'amount': amount,
      'description': description,
    });
  }
}
