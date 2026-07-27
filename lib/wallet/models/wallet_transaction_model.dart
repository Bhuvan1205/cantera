import 'package:cloud_firestore/cloud_firestore.dart';

/// The type of a wallet transaction.
enum WalletTransactionType {
  deposit,    // Money added to wallet (via payment gateway)
  purchase,   // Credits spent on an order
  refund,     // Credits returned after order cancellation
  adjustment, // Manual admin adjustment
  bonus,      // Promotional/bonus credits
  cashback,   // Cashback earned
  reversal;   // Reversal of a failed operation

  static WalletTransactionType fromString(String? value) {
    switch (value) {
      case 'deposit': return WalletTransactionType.deposit;
      case 'purchase': return WalletTransactionType.purchase;
      case 'refund': return WalletTransactionType.refund;
      case 'adjustment': return WalletTransactionType.adjustment;
      case 'bonus': return WalletTransactionType.bonus;
      case 'cashback': return WalletTransactionType.cashback;
      case 'reversal': return WalletTransactionType.reversal;
      default: return WalletTransactionType.deposit;
    }
  }

  String get label {
    switch (this) {
      case WalletTransactionType.deposit: return 'Wallet Top-up';
      case WalletTransactionType.purchase: return 'Order Payment';
      case WalletTransactionType.refund: return 'Refund';
      case WalletTransactionType.adjustment: return 'Admin Adjustment';
      case WalletTransactionType.bonus: return 'Bonus Received';
      case WalletTransactionType.cashback: return 'Cashback Earned';
      case WalletTransactionType.reversal: return 'Transaction Reversal';
    }
  }

  String get firestoreValue {
    switch (this) {
      case WalletTransactionType.deposit: return 'deposit';
      case WalletTransactionType.purchase: return 'purchase';
      case WalletTransactionType.refund: return 'refund';
      case WalletTransactionType.adjustment: return 'adjustment';
      case WalletTransactionType.bonus: return 'bonus';
      case WalletTransactionType.cashback: return 'cashback';
      case WalletTransactionType.reversal: return 'reversal';
    }
  }
}

/// The lifecycle status of a wallet transaction.
enum WalletTransactionStatus {
  pending,
  success,
  failed,
  cancelled;

  static WalletTransactionStatus fromString(String? value) {
    switch (value) {
      case 'pending': return WalletTransactionStatus.pending;
      case 'success': return WalletTransactionStatus.success;
      case 'failed': return WalletTransactionStatus.failed;
      case 'cancelled': return WalletTransactionStatus.cancelled;
      default: return WalletTransactionStatus.pending;
    }
  }

  String get firestoreValue {
    switch (this) {
      case WalletTransactionStatus.pending: return 'pending';
      case WalletTransactionStatus.success: return 'success';
      case WalletTransactionStatus.failed: return 'failed';
      case WalletTransactionStatus.cancelled: return 'cancelled';
    }
  }
}

/// Represents a single entry in the `wallet_transactions` immutable ledger.
///
/// Transactions are **never modified** after creation — they form the
/// complete audit trail for all wallet balance changes.
class WalletTransactionModel {
  final String id;
  final String userId;
  final WalletTransactionType type;
  final double amount;
  final WalletTransactionStatus status;
  final String description;
  final String? orderId;             // Retained for backward compatibility
  final String? paymentRef;          // Razorpay payment_id for deposits
  final String? gateway;             // 'razorpay' | 'mock' | null
  final String initiatedBy;          // user_uid | 'admin:{uid}' | 'system'
  final DateTime timestamp;
  final double balanceAfter;         // Wallet balance after this transaction
  final String? idempotencyKey;      // Prevents double-processing (= payment_id)
  final String? referenceType;       // 'order' | 'pending_deposit' | 'refund_request' | 'adjustment'
  final String? referenceId;         // document ID of the associated entity

  const WalletTransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.status,
    required this.description,
    this.orderId,
    this.paymentRef,
    this.gateway,
    required this.initiatedBy,
    required this.timestamp,
    required this.balanceAfter,
    this.idempotencyKey,
    this.referenceType,
    this.referenceId,
  });

  factory WalletTransactionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return WalletTransactionModel(
      id: doc.id,
      userId: data['user_uid'] as String? ?? '',
      type: WalletTransactionType.fromString(data['type'] as String?),
      amount: ((data['amount'] ?? 0.0) as num).toDouble(),
      status: WalletTransactionStatus.fromString(data['status'] as String?),
      description: data['description'] as String? ?? '',
      orderId: data['order_id'] as String?,
      paymentRef: data['payment_ref'] as String?,
      gateway: data['gateway'] as String?,
      initiatedBy: data['initiated_by'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      balanceAfter: ((data['balance_after'] ?? 0.0) as num).toDouble(),
      idempotencyKey: data['idempotency_key'] as String?,
      referenceType: data['reference_type'] as String?,
      referenceId: data['reference_id'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'user_uid': userId,
    'type': type.firestoreValue,
    'amount': amount,
    'status': status.firestoreValue,
    'description': description,
    if (orderId != null) 'order_id': orderId,
    if (paymentRef != null) 'payment_ref': paymentRef,
    if (gateway != null) 'gateway': gateway,
    'initiated_by': initiatedBy,
    'timestamp': FieldValue.serverTimestamp(),
    'balance_after': balanceAfter,
    if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
    if (referenceType != null) 'reference_type': referenceType,
    if (referenceId != null) 'reference_id': referenceId,
  };

  /// True when this transaction credits the wallet (deposit, refund, adjustment, bonus, cashback, reversal).
  bool get isCredit =>
      type == WalletTransactionType.deposit ||
      type == WalletTransactionType.refund ||
      type == WalletTransactionType.adjustment ||
      type == WalletTransactionType.bonus ||
      type == WalletTransactionType.cashback ||
      type == WalletTransactionType.reversal;

  /// True when this transaction debits the wallet (purchase).
  bool get isDebit => type == WalletTransactionType.purchase;

  @override
  String toString() =>
      'WalletTransactionModel(id: $id, type: $type, amount: $amount, status: $status, referenceType: $referenceType, referenceId: $referenceId)';
}
