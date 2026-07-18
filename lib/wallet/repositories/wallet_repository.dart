import '../models/pending_deposit_model.dart';
import '../models/refund_request_model.dart';
import '../models/wallet_model.dart';
import '../models/wallet_transaction_model.dart';

/// Abstract interface for all wallet data operations.
///
/// Implementations:
///  - [FirestoreWalletRepository]: production Firestore backend
///
/// All balance-modifying operations (approve/reject deposits, purchase,
/// refund) use Firestore Transactions internally to ensure atomicity.
abstract class WalletRepository {
  // ── Wallet reads ───────────────────────────────────────────────────────────

  /// Live stream of the user's wallet document.
  /// Emits null if the wallet has not been created yet.
  Stream<WalletModel?> watchWallet(String userId);

  /// One-time fetch of the user's wallet.
  Future<WalletModel?> getWallet(String userId);

  // ── Transaction reads ──────────────────────────────────────────────────────

  /// Live stream of the user's wallet transactions, newest first.
  Stream<List<WalletTransactionModel>> watchTransactions(
    String userId, {
    int limit = 50,
  });

  /// One-time fetch of wallet transactions with optional type filter.
  Future<List<WalletTransactionModel>> getTransactions(
    String userId, {
    int limit = 50,
    WalletTransactionType? type,
  });

  // ── Pending deposit reads ──────────────────────────────────────────────────

  /// Live stream of the user's own pending deposits.
  Stream<List<PendingDepositModel>> watchUserPendingDeposits(String userId);

  /// Admin: live stream of ALL pending deposits awaiting review.
  Stream<List<PendingDepositModel>> watchAllPendingDeposits();

  // ── Refund request reads ───────────────────────────────────────────────────

  /// Live stream of the user's own refund requests.
  Stream<List<RefundRequestModel>> watchUserRefundRequests(String userId);

  /// Admin: live stream of ALL pending refund requests.
  Stream<List<RefundRequestModel>> watchAllRefundRequests();

  // ── Client staging writes ──────────────────────────────────────────────────

  /// Creates a pending deposit record after a successful payment.
  /// Returns the Firestore document ID of the new pending deposit.
  Future<String> createPendingDeposit({
    required String userId,
    required double amount,
    required String razorpayPaymentId,
    String? razorpayOrderId,
    String? razorpaySignature,
    required String gateway,
  });

  /// Creates a refund request for an order still in 'placed' status.
  /// Throws if the order is not in 'placed' status.
  Future<void> createRefundRequest({
    required String userId,
    required String orderId,
    required double amount,
    String? reason,
  });

  // ── Wallet purchase (Firestore Transaction, client-callable) ───────────────

  /// Atomically deducts [amount] from the user's wallet and creates a
  /// `wallet_transactions` record.
  ///
  /// Throws if balance is insufficient.
  Future<void> purchaseWithWallet({
    required String userId,
    required double amount,
    required String orderId,
    required String description,
  });

  // ── Admin-only writes (enforced by Firestore Security Rules) ──────────────

  /// Approves a pending deposit: credits the wallet and marks the deposit approved.
  Future<void> approveDeposit(String depositId, String adminUid);

  /// Rejects a pending deposit without modifying the wallet.
  Future<void> rejectDeposit(
    String depositId,
    String adminUid,
    String reason,
  );

  /// Moves a refund request to 'refund_under_review' status.
  Future<void> reviewRefund(String requestId, String adminUid);

  /// Approves a refund request: moves status to 'approved' and then 'credited' while performing the wallet credit.
  Future<void> approveRefund(String requestId, String adminUid);

  /// Rejects a refund request: moves status to 'rejected' and reverts order status.
  Future<void> rejectRefund(
    String requestId,
    String adminUid,
    String reason,
  );

  /// Creates a manual wallet adjustment (admin use only).
  Future<void> createAdjustment({
    required String userId,
    required double amount,
    required String description,
    required String adminUid,
  });
}
