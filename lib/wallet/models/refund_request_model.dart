import 'package:cloud_firestore/cloud_firestore.dart';

/// Status lifecycle for a refund request.
enum RefundRequestStatus {
  refundRequested,
  refundUnderReview,
  approved,
  credited,
  rejected;

  static RefundRequestStatus fromString(String? value) {
    switch (value) {
      case 'refund_requested':
      case 'pending': // fallback for legacy
        return RefundRequestStatus.refundRequested;
      case 'refund_under_review':
        return RefundRequestStatus.refundUnderReview;
      case 'approved':
        return RefundRequestStatus.approved;
      case 'credited':
        return RefundRequestStatus.credited;
      case 'rejected':
        return RefundRequestStatus.rejected;
      default:
        return RefundRequestStatus.refundRequested;
    }
  }

  String get firestoreValue {
    switch (this) {
      case RefundRequestStatus.refundRequested:
        return 'refund_requested';
      case RefundRequestStatus.refundUnderReview:
        return 'refund_under_review';
      case RefundRequestStatus.approved:
        return 'approved';
      case RefundRequestStatus.credited:
        return 'credited';
      case RefundRequestStatus.rejected:
        return 'rejected';
    }
  }

  String get label {
    switch (this) {
      case RefundRequestStatus.refundRequested:
        return 'Requested';
      case RefundRequestStatus.refundUnderReview:
        return 'Under Review';
      case RefundRequestStatus.approved:
        return 'Approved';
      case RefundRequestStatus.credited:
        return 'Credited';
      case RefundRequestStatus.rejected:
        return 'Rejected';
    }
  }
}

/// A refund request created by the user for an order still in 'placed' status.
///
/// Lives in `refund_requests/{request_id}`.
class RefundRequestModel {
  final String id;
  final String userId;
  final String orderId;
  final double amount;
  final RefundRequestStatus status;
  final String? reason;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? rejectionReason;

  const RefundRequestModel({
    required this.id,
    required this.userId,
    required this.orderId,
    required this.amount,
    required this.status,
    this.reason,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
    this.resolvedAt,
    this.resolvedBy,
    this.rejectionReason,
  });

  factory RefundRequestModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return RefundRequestModel(
      id: doc.id,
      userId: data['user_uid'] as String? ?? '',
      orderId: data['order_id'] as String? ?? '',
      amount: ((data['amount'] ?? 0.0) as num).toDouble(),
      status: RefundRequestStatus.fromString(data['status'] as String?),
      reason: data['reason'] as String?,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (data['reviewed_at'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewed_by'] as String?,
      resolvedAt: (data['resolved_at'] as Timestamp?)?.toDate(),
      resolvedBy: data['resolved_by'] as String?,
      rejectionReason: data['rejection_reason'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'user_uid': userId,
    'order_id': orderId,
    'amount': amount,
    'status': status.firestoreValue,
    if (reason != null) 'reason': reason,
    'created_at': FieldValue.serverTimestamp(),
    if (reviewedAt != null) 'reviewed_at': Timestamp.fromDate(reviewedAt!),
    if (reviewedBy != null) 'reviewed_by': reviewedBy,
    if (resolvedAt != null) 'resolved_at': Timestamp.fromDate(resolvedAt!),
    if (resolvedBy != null) 'resolved_by': resolvedBy,
    if (rejectionReason != null) 'rejection_reason': rejectionReason,
  };

  bool get isPending =>
      status == RefundRequestStatus.refundRequested ||
      status == RefundRequestStatus.refundUnderReview;
}
