// ignore_for_file: avoid_catches_without_on_clauses

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pending_deposit_model.dart';
import '../models/refund_request_model.dart';
import '../models/wallet_model.dart';
import '../models/wallet_transaction_model.dart';
import 'wallet_repository.dart';

/// Production Firestore implementation of [WalletRepository].
///
/// All balance-modifying operations run inside `runTransaction()` for
/// atomic read-modify-write semantics. This prevents race conditions
/// when multiple purchases/deposits happen concurrently for the same user.
class FirestoreWalletRepository implements WalletRepository {
  static final _db = FirebaseFirestore.instance;

  static final _walletsCol = _db.collection('wallets');
  static final _transactionsCol = _db.collection('wallet_transactions');
  static final _pendingDepositsCol = _db.collection('pending_deposits');
  static final _refundRequestsCol = _db.collection('refund_requests');
  static final _ordersCol = _db.collection('Orders');

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

  // ── Client staging writes ──────────────────────────────────────────────────

  @override
  Future<String> createPendingDeposit({
    required String userId,
    required double amount,
    required String razorpayPaymentId,
    String? razorpayOrderId,
    String? razorpaySignature,
    required String gateway,
  }) async {
    final docRef = _pendingDepositsCol.doc();
    final data = <String, dynamic>{
      'user_uid': userId,
      'amount': amount,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_order_id': razorpayOrderId,
      'razorpay_signature': razorpaySignature,
      'gateway': gateway,
      'status': 'awaiting_review',
      'created_at': FieldValue.serverTimestamp(),
    };
    await docRef.set(data);
    return docRef.id;
  }

  @override
  Future<void> createRefundRequest({
    required String userId,
    required String orderId,
    required double amount,
    String? reason,
  }) async {
    // Validate: order must exist and be in 'placed' status.
    final orderSnap = await _ordersCol.doc(orderId).get();
    if (!orderSnap.exists) {
      throw Exception('Order not found.');
    }
    final orderData = orderSnap.data();
    final orderStatus = (orderData?['status'] as String? ?? '').toLowerCase();
    if (orderStatus != 'placed') {
      throw Exception(
        'Refunds can only be requested for orders that have not yet been prepared.',
      );
    }
    if ((orderData?['userId'] as String?) != userId) {
      throw Exception('You can only request a refund for your own orders.');
    }

    await _db.runTransaction((tx) async {
      // Re-read order inside transaction for consistency.
      final orderRef = _ordersCol.doc(orderId);
      final orderDoc = await tx.get(orderRef);
      final status =
          (orderDoc.data()?['status'] as String? ?? '')
              .toLowerCase();
      if (status != 'placed') {
        throw Exception(
          'Refund cannot be requested — order has already been processed.',
        );
      }

      final refundRef = _refundRequestsCol.doc();
      tx.set(refundRef, {
        'user_uid': userId,
        'order_id': orderId,
        'amount': amount,
        'status': 'refund_requested',
        'reason': reason,
        'created_at': FieldValue.serverTimestamp(),
      });

      // Mark order as refund_pending to prevent double refund requests.
      tx.update(orderRef, {'status': 'refund_pending'});
    });
  }

  // ── Wallet purchase ────────────────────────────────────────────────────────

  @override
  Future<void> purchaseWithWallet({
    required String userId,
    required double amount,
    required String orderId,
    required String description,
  }) async {
    final walletRef = _walletsCol.doc(userId);
    final txRef = _transactionsCol.doc(orderId);

    await _db.runTransaction((tx) async {
      final walletSnap = await tx.get(walletRef);

      double currentBalance;
      if (!walletSnap.exists) {
        throw Exception('Wallet not found. Please set up your wallet first.');
      }
      currentBalance =
          ((walletSnap.data()?['balance'] ?? 0.0) as num).toDouble();

      if (currentBalance < amount) {
        throw Exception(
          'Insufficient wallet balance. '
          'Available: ₹${currentBalance.toStringAsFixed(2)}, '
          'Required: ₹${amount.toStringAsFixed(2)}.',
        );
      }

      final newBalance = currentBalance - amount;
      final currentSpent =
          ((walletSnap.data()?['total_spent'] ?? 0.0) as num).toDouble();

      // Deduct from wallet.
      tx.update(walletRef, {
        'balance': newBalance,
        'total_spent': currentSpent + amount,
        'last_updated': FieldValue.serverTimestamp(),
        'last_order_id': orderId,
      });

      // Create immutable transaction record.
      tx.set(txRef, {
        'user_uid': userId,
        'type': 'purchase',
        'amount': amount,
        'status': 'success',
        'description': description,
        'order_id': orderId,
        'initiated_by': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'balance_after': newBalance,
        'reference_type': 'order',
        'reference_id': orderId,
      });
    });
  }

  // ── Admin-only writes ──────────────────────────────────────────────────────

  @override
  Future<void> approveDeposit(String depositId, String adminUid) async {
    final depositRef = _pendingDepositsCol.doc(depositId);

    // Read deposit outside transaction first for amount/userId.
    final depositSnap = await depositRef.get();
    if (!depositSnap.exists) throw Exception('Deposit request not found.');
    final depositData = depositSnap.data() as Map<String, dynamic>;

    if (depositData['status'] != 'awaiting_review') {
      throw Exception('This deposit has already been processed.');
    }

    final userId = depositData['user_uid'] as String;
    final amount = (depositData['amount'] as num).toDouble();
    final paymentId = depositData['razorpay_payment_id'] as String;
    final gateway = depositData['gateway'] as String? ?? 'razorpay';

    final walletRef = _walletsCol.doc(userId);
    final txRef = _transactionsCol.doc();

    await _db.runTransaction((tx) async {
      // Re-read deposit inside transaction to prevent double-approve.
      final dSnap = await tx.get(depositRef);
      final dData = dSnap.data();
      if (dData == null || dData['status'] != 'awaiting_review') {
        throw Exception('Deposit already processed (concurrent approval detected).');
      }

      final walletSnap = await tx.get(walletRef);
      double currentBalance = 0.0;
      double currentTotal = 0.0;

      if (!walletSnap.exists) {
        // Create wallet on first deposit.
        tx.set(walletRef, {
          'balance': amount,
          'total_added': amount,
          'total_spent': 0.0,
          'created_at': FieldValue.serverTimestamp(),
          'last_updated': FieldValue.serverTimestamp(),
        });
      } else {
        final wData = walletSnap.data();
        currentBalance = ((wData?['balance'] ?? 0.0) as num).toDouble();
        currentTotal = ((wData?['total_added'] ?? 0.0) as num).toDouble();
        tx.update(walletRef, {
          'balance': currentBalance + amount,
          'total_added': currentTotal + amount,
          'last_updated': FieldValue.serverTimestamp(),
        });
      }

      final newBalance = currentBalance + amount;

      // Immutable transaction record.
      tx.set(txRef, {
        'user_uid': userId,
        'type': 'deposit',
        'amount': amount,
        'status': 'success',
        'description': 'Wallet top-up via ${gateway == 'mock' ? 'Mock Gateway' : 'Razorpay'}',
        'payment_ref': paymentId,
        'gateway': gateway,
        'initiated_by': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'balance_after': newBalance,
        'idempotency_key': paymentId,
        'reference_type': 'pending_deposit',
        'reference_id': depositId,
      });

      // Mark deposit approved.
      tx.update(depositRef, {
        'status': 'approved',
        'reviewed_at': FieldValue.serverTimestamp(),
        'reviewed_by': adminUid,
      });
    });
  }

  @override
  Future<void> rejectDeposit(
    String depositId,
    String adminUid,
    String reason,
  ) async {
    await _pendingDepositsCol.doc(depositId).update({
      'status': 'rejected',
      'reviewed_at': FieldValue.serverTimestamp(),
      'reviewed_by': adminUid,
      'rejection_reason': reason,
    });
  }

  @override
  Future<void> reviewRefund(String requestId, String adminUid) async {
    await _refundRequestsCol.doc(requestId).update({
      'status': 'refund_under_review',
      'reviewed_at': FieldValue.serverTimestamp(),
      'reviewed_by': adminUid,
    });
  }

  @override
  Future<void> approveRefund(String requestId, String adminUid) async {
    final requestRef = _refundRequestsCol.doc(requestId);
    final requestSnap = await requestRef.get();
    if (!requestSnap.exists) throw Exception('Refund request not found.');
    final requestData = requestSnap.data() as Map<String, dynamic>;
    final currentStatus = requestData['status'] as String?;
    if (currentStatus == 'credited' || currentStatus == 'rejected') {
      throw Exception('This refund request has already been resolved.');
    }

    final userId = requestData['user_uid'] as String;
    final orderId = requestData['order_id'] as String;
    final amount = (requestData['amount'] as num).toDouble();

    final walletRef = _walletsCol.doc(userId);
    final txRef = _transactionsCol.doc();
    final orderRef = _ordersCol.doc(orderId);

    await _db.runTransaction((tx) async {
      final rSnap = await tx.get(requestRef);
      final rData = rSnap.data();
      if (rData == null) throw Exception('Refund request not found.');
      final statusVal = rData['status'] as String?;
      if (statusVal == 'credited' || statusVal == 'rejected') {
        throw Exception('Refund request already resolved.');
      }

      final walletSnap = await tx.get(walletRef);
      double currentBalance = 0.0;
      double currentTotal = 0.0;

      if (!walletSnap.exists) {
        tx.set(walletRef, {
          'balance': amount,
          'total_added': amount,
          'total_spent': 0.0,
          'created_at': FieldValue.serverTimestamp(),
          'last_updated': FieldValue.serverTimestamp(),
        });
      } else {
        final wData = walletSnap.data();
        currentBalance = ((wData?['balance'] ?? 0.0) as num).toDouble();
        currentTotal = ((wData?['total_added'] ?? 0.0) as num).toDouble();
        tx.update(walletRef, {
          'balance': currentBalance + amount,
          'total_added': currentTotal + amount,
          'last_updated': FieldValue.serverTimestamp(),
        });
      }

      final newBalance = currentBalance + amount;

      tx.set(txRef, {
        'user_uid': userId,
        'type': 'refund',
        'amount': amount,
        'status': 'success',
        'description': 'Refund for order #${orderId.substring(0, 4).toUpperCase()}',
        'order_id': orderId,
        'initiated_by': 'admin:$adminUid',
        'timestamp': FieldValue.serverTimestamp(),
        'balance_after': newBalance,
        'reference_type': 'refund_request',
        'reference_id': requestId,
      });

      tx.update(requestRef, {
        'status': 'credited',
        'resolved_at': FieldValue.serverTimestamp(),
        'resolved_by': adminUid,
      });

      // Cancel the order.
      tx.update(orderRef, {'status': 'cancelled', 'overall_status': 'cancelled'});
    });
  }

  @override
  Future<void> rejectRefund(
    String requestId,
    String adminUid,
    String reason,
  ) async {
    final requestSnap = await _refundRequestsCol.doc(requestId).get();
    final orderId = requestSnap.data()?['order_id'] as String?;

    final batch = _db.batch();
    batch.update(_refundRequestsCol.doc(requestId), {
      'status': 'rejected',
      'resolved_at': FieldValue.serverTimestamp(),
      'resolved_by': adminUid,
      'rejection_reason': reason,
    });
    if (orderId != null) {
      // Revert the order back to 'placed' so it can continue processing.
      batch.update(_ordersCol.doc(orderId), {'status': 'placed'});
    }
    await batch.commit();
  }

  @override
  Future<void> createAdjustment({
    required String userId,
    required double amount,
    required String description,
    required String adminUid,
  }) async {
    final walletRef = _walletsCol.doc(userId);
    final txRef = _transactionsCol.doc();

    await _db.runTransaction((tx) async {
      final walletSnap = await tx.get(walletRef);
      double currentBalance = 0.0;
      double currentTotal = 0.0;

      if (!walletSnap.exists) {
        tx.set(walletRef, {
          'balance': amount,
          'total_added': amount,
          'total_spent': 0.0,
          'created_at': FieldValue.serverTimestamp(),
          'last_updated': FieldValue.serverTimestamp(),
        });
      } else {
        final wData = walletSnap.data();
        currentBalance = ((wData?['balance'] ?? 0.0) as num).toDouble();
        currentTotal = ((wData?['total_added'] ?? 0.0) as num).toDouble();
        final newBalance =
            (currentBalance + amount).clamp(0.0, double.infinity);
        tx.update(walletRef, {
          'balance': newBalance,
          'total_added': amount > 0 ? currentTotal + amount : currentTotal,
          'last_updated': FieldValue.serverTimestamp(),
        });
      }

      final newBalance = (currentBalance + amount).clamp(0.0, double.infinity);
      tx.set(txRef, {
        'user_uid': userId,
        'type': 'adjustment',
        'amount': amount.abs(),
        'status': 'success',
        'description': description,
        'initiated_by': 'admin:$adminUid',
        'timestamp': FieldValue.serverTimestamp(),
        'balance_after': newBalance,
        'reference_type': 'adjustment',
        'reference_id': adminUid,
      });
    });
  }
}
