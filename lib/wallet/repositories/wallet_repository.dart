import '../models/pending_deposit_model.dart';
import '../models/refund_request_model.dart';
import '../models/wallet_model.dart';
import '../models/wallet_transaction_model.dart';

/// Abstract interface for read-only wallet data streaming and fetching.
///
/// Implementations:
///  - [FirestoreWalletRepository]: read-only Firestore stream and query provider
///
/// Under ADR-001 (Backend-First Architecture), all balance mutations, deposits,
/// and refund status changes execute exclusively in the FastAPI backend on Cloud Run.
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
}
