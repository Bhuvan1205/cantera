import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the user's wallet document from `wallets/{user_uid}`.
///
/// The wallet balance is a **cached value** for fast reads.
/// The true source of truth is the `wallet_transactions` ledger.
///
/// All writes to this document are restricted to admin-level access only
/// via Firestore Security Rules — users can never directly modify their balance.
class WalletModel {
  final String userId;       // == Firestore document ID
  final double balance;      // Current credits in ₹ (always ≥ 0)
  final double totalAdded;   // Lifetime deposits
  final double totalSpent;   // Lifetime purchases
  final DateTime createdAt;
  final DateTime lastUpdated;
  final String? lastOrderId;  // Links to the last order paid via wallet

  const WalletModel({
    required this.userId,
    required this.balance,
    required this.totalAdded,
    required this.totalSpent,
    required this.createdAt,
    required this.lastUpdated,
    this.lastOrderId,
  });

  // ── Factory constructors ──────────────────────────────────────────────────

  factory WalletModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return WalletModel(
      userId: doc.id,
      balance: ((data['balance'] ?? 0.0) as num).toDouble(),
      totalAdded: ((data['total_added'] ?? 0.0) as num).toDouble(),
      totalSpent: ((data['total_spent'] ?? 0.0) as num).toDouble(),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastUpdated: (data['last_updated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastOrderId: data['last_order_id'] as String?,
    );
  }

  /// Creates an empty wallet for a new user (balance = 0).
  factory WalletModel.empty(String userId) {
    final now = DateTime.now();
    return WalletModel(
      userId: userId,
      balance: 0.0,
      totalAdded: 0.0,
      totalSpent: 0.0,
      createdAt: now,
      lastUpdated: now,
      lastOrderId: null,
    );
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
    'balance': balance,
    'total_added': totalAdded,
    'total_spent': totalSpent,
    'created_at': Timestamp.fromDate(createdAt),
    'last_updated': FieldValue.serverTimestamp(),
    if (lastOrderId != null) 'last_order_id': lastOrderId,
  };

  // ── Convenience ───────────────────────────────────────────────────────────

  /// Returns true if [amount] can be deducted without going negative.
  bool hasSufficientBalance(double amount) => balance >= amount;

  /// Formatted balance string, e.g. `₹250.00`.
  String get formattedBalance =>
      '₹${balance.toStringAsFixed(2)}';

  @override
  String toString() =>
      'WalletModel(userId: $userId, balance: $balance, totalAdded: $totalAdded, totalSpent: $totalSpent, lastOrderId: $lastOrderId)';
}
