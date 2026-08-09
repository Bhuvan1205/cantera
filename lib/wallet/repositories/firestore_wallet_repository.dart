import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pending_deposit_model.dart';
import '../models/refund_request_model.dart';
import '../models/wallet_model.dart';
import '../models/wallet_transaction_model.dart';
import 'wallet_repository.dart';

/// Production Firestore read-only implementation of [WalletRepository].
///
/// Provides live reactive streams and snapshot reads for the UI.
/// Under ADR-001, all write mutations execute exclusively on the FastAPI backend.
class FirestoreWalletRepository implements WalletRepository {
  static final _db = FirebaseFirestore.instance;

  static final _walletsCol = _db.collection('wallets');
  static final _transactionsCol = _db.collection('wallet_transactions');
  static final _pendingDepositsCol = _db.collection('pending_deposits');
  static final _refundRequestsCol = _db.collection('refund_requests');

  // ── Wallet reads ───────────────────────────────────────────────────────────

  @override
  Stream<WalletModel?> watchWallet(String userId) {
    return _walletsCol
        .doc(userId)
        .snapshots()
        .map((snap) {
          if (!snap.exists) return null;
          return WalletModel.fromFirestore(snap);
        });
  }

  @override
  Future<WalletModel?> getWallet(String userId) async {
    final snap = await _walletsCol.doc(userId).get();
    if (!snap.exists) return null;
    return WalletModel.fromFirestore(snap);
  }

  // ── Transaction reads ──────────────────────────────────────────────────────

  @override
  Stream<List<WalletTransactionModel>> watchTransactions(
    String userId, {
    int limit = 50,
  }) {
    return _transactionsCol
        .where('user_uid', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final txs = snap.docs
              .map((doc) => WalletTransactionModel.fromFirestore(
                    doc as DocumentSnapshot<Map<String, dynamic>>,
                  ))
              .toList();
          txs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return txs.take(limit).toList();
        });
  }

  @override
  Future<List<WalletTransactionModel>> getTransactions(
    String userId, {
    int limit = 50,
    WalletTransactionType? type,
  }) async {
    Query<Map<String, dynamic>> query = _transactionsCol
        .where('user_uid', isEqualTo: userId);

    if (type != null) {
      query = query.where('type', isEqualTo: type.firestoreValue);
    }

    final snap = await query.get();
    final txs = snap.docs
        .map((doc) => WalletTransactionModel.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ))
        .toList();
    txs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return txs.take(limit).toList();
  }

  // ── Pending deposit reads ──────────────────────────────────────────────────

  @override
  Stream<List<PendingDepositModel>> watchUserPendingDeposits(String userId) {
    return _pendingDepositsCol
        .where('user_uid', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final deposits = snap.docs
              .map((doc) => PendingDepositModel.fromFirestore(
                    doc as DocumentSnapshot<Map<String, dynamic>>,
                  ))
              .toList();
          deposits.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return deposits;
        });
  }

  @override
  Stream<List<PendingDepositModel>> watchAllPendingDeposits() {
    return _pendingDepositsCol
        .snapshots()
        .map((snap) {
          final deposits = snap.docs
              .map((doc) => PendingDepositModel.fromFirestore(snapDoc(doc)))
              .toList();
          deposits.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return deposits;
        });
  }

  // ── Refund request reads ───────────────────────────────────────────────────

  @override
  Stream<List<RefundRequestModel>> watchUserRefundRequests(String userId) {
    return _refundRequestsCol
        .where('user_uid', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final requests = snap.docs
              .map((doc) => RefundRequestModel.fromFirestore(
                    doc as DocumentSnapshot<Map<String, dynamic>>,
                  ))
              .toList();
          requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return requests;
        });
  }

  @override
  Stream<List<RefundRequestModel>> watchAllRefundRequests() {
    return _refundRequestsCol
        .snapshots()
        .map((snap) {
          final requests = snap.docs
              .map((doc) => RefundRequestModel.fromFirestore(snapDoc(doc)))
              .toList();
          requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return requests;
        });
  }

  // Helper method to keep cast clean
  static DocumentSnapshot<Map<String, dynamic>> snapDoc(DocumentSnapshot doc) =>
      doc as DocumentSnapshot<Map<String, dynamic>>;
}
