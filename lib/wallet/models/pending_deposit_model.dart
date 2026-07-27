import 'package:cloud_firestore/cloud_firestore.dart';

/// Status lifecycle of a pending deposit request.
enum PendingDepositStatus {
  awaitingReview,
  approved,
  rejected;

  static PendingDepositStatus fromString(String? value) {
    switch (value) {
      case 'approved': return PendingDepositStatus.approved;
      case 'rejected': return PendingDepositStatus.rejected;
      default: return PendingDepositStatus.awaitingReview;
    }
  }

  String get firestoreValue {
    switch (this) {
      case PendingDepositStatus.awaitingReview: return 'awaiting_review';
      case PendingDepositStatus.approved: return 'approved';
      case PendingDepositStatus.rejected: return 'rejected';
    }
  }

  String get label {
    switch (this) {
      case PendingDepositStatus.awaitingReview: return 'Pending Review';
      case PendingDepositStatus.approved: return 'Approved';
      case PendingDepositStatus.rejected: return 'Rejected';
    }
  }
}

/// A deposit request created by the client after a successful payment.
///
/// Lives in `pending_deposits/{deposit_id}`. The admin reviews and approves
/// these, which triggers the actual wallet credit via a Firestore Transaction.
///
/// On Spark Plan: admin manually approves.
/// On Blaze Plan: a Cloud Function auto-approves verified payments.
class PendingDepositModel {
  final String id;
  final String userId;
  final double amount;
  final String razorpayPaymentId;  // Primary payment proof
  final String? razorpayOrderId;   // Optional (only if server-generated order)
  final String? razorpaySignature; // Optional (requires server secret to verify)
  final String gateway;            // 'razorpay' | 'mock'
  final PendingDepositStatus status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;        // Admin uid
  final String? rejectionReason;

  const PendingDepositModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.razorpayPaymentId,
    this.razorpayOrderId,
    this.razorpaySignature,
    required this.gateway,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
  });

  factory PendingDepositModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return PendingDepositModel(
      id: doc.id,
      userId: data['user_uid'] as String? ?? '',
      amount: ((data['amount'] ?? 0.0) as num).toDouble(),
      razorpayPaymentId: data['razorpay_payment_id'] as String? ?? '',
      razorpayOrderId: data['razorpay_order_id'] as String?,
      razorpaySignature: data['razorpay_signature'] as String?,
      gateway: data['gateway'] as String? ?? 'razorpay',
      status: PendingDepositStatus.fromString(data['status'] as String?),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (data['reviewed_at'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewed_by'] as String?,
      rejectionReason: data['rejection_reason'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'user_uid': userId,
    'amount': amount,
    'razorpay_payment_id': razorpayPaymentId,
    if (razorpayOrderId != null) 'razorpay_order_id': razorpayOrderId,
    if (razorpaySignature != null) 'razorpay_signature': razorpaySignature,
    'gateway': gateway,
    'status': status.firestoreValue,
    'created_at': FieldValue.serverTimestamp(),
  };

  bool get isPending => status == PendingDepositStatus.awaitingReview;
}
