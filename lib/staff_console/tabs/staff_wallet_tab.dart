import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../wallet/models/pending_deposit_model.dart';
import '../../../wallet/models/refund_request_model.dart';
import '../../../wallet/services/wallet_service.dart';
import '../../../wallet/utils/wallet_formatters.dart';

/// Admin tab showing pending wallet deposits and refund requests.
///
/// Accessible from the admin dashboard as a tab. Admins can approve or
/// reject deposits and refunds from here.
///
/// Security: write operations (approve/reject) require `isAdmin == true`
/// enforced by Firestore Security Rules — client-side checks are UX only.
class StaffWalletTab extends StatefulWidget {
  const StaffWalletTab({super.key});

  @override
  State<StaffWalletTab> createState() => _StaffWalletTabState();
}

class _StaffWalletTabState extends State<StaffWalletTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Tab bar ──────────────────────────────────────────────────────────
        Container(
          color: AppColors.bg,
          child: TabBar(
            controller: _tabs,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            tabs: const [
              Tab(text: 'Deposits'),
              Tab(text: 'Refunds'),
            ],
          ),
        ),

        // ── Tab views ────────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _DepositRequestsList(),
              _RefundRequestsList(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Deposit Requests List ─────────────────────────────────────────────────────

class _DepositRequestsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PendingDepositModel>>(
      stream: WalletService.watchAllPendingDeposits(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        final deposits = snap.data ?? [];
        if (deposits.isEmpty) {
          return const _EmptyState(
            icon: Icons.check_circle_outline_rounded,
            message: 'No pending deposits',
            subtitle: 'All deposits have been reviewed.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: deposits.length,
          separatorBuilder: (_, index) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _DepositCard(deposit: deposits[i]),
        );
      },
    );
  }
}

class _DepositCard extends StatefulWidget {
  const _DepositCard({required this.deposit});
  final PendingDepositModel deposit;

  @override
  State<_DepositCard> createState() => _DepositCardState();
}

class _DepositCardState extends State<_DepositCard> {
  bool _isActing = false;

  Future<void> _approve() async {
    setState(() => _isActing = true);
    try {
      final adminUid = FirebaseAuth.instance.currentUser!.uid;
      await WalletService.approveDeposit(widget.deposit.id, adminUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deposit of ${WalletFormatters.currency(widget.deposit.amount)} approved.',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActing = false);
      _showError(e.toString());
    }
  }

  Future<void> _reject() async {
    final reason = await _showRejectDialog(context, 'Reject Deposit');
    if (reason == null || !mounted) return;
    setState(() => _isActing = true);
    try {
      final adminUid = FirebaseAuth.instance.currentUser!.uid;
      await WalletService.rejectDeposit(widget.deposit.id, adminUid, reason);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActing = false);
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Amount + gateway badge
          Row(
            children: [
              Text(
                WalletFormatters.currency(widget.deposit.amount),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              _GatewayBadge(gateway: widget.deposit.gateway),
            ],
          ),
          const SizedBox(height: 12),
          // Payment ID
          _DetailRow(
            label: 'Payment ID',
            value: widget.deposit.razorpayPaymentId,
            monospace: true,
          ),
          const SizedBox(height: 6),
          // Date
          _DetailRow(
            label: 'Submitted',
            value: WalletFormatters.dateTime(widget.deposit.createdAt),
          ),
          const SizedBox(height: 6),
          // User Name & UID
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance.collection('Users').doc(widget.deposit.userId).get(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();
              final name = (data?['name'] as String?)?.trim();
              final displayName = name == null || name.isEmpty ? 'Customer' : name;
              return _DetailRow(
                label: 'User',
                value: '$displayName (${widget.deposit.userId.substring(0, 5)}...)',
              );
            },
          ),
          const SizedBox(height: 18),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),
          // Actions
          if (widget.deposit.status != PendingDepositStatus.awaitingReview)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: widget.deposit.status == PendingDepositStatus.approved
                    ? AppColors.success.withValues(alpha: 0.08)
                    : AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.deposit.status == PendingDepositStatus.approved
                    ? '✓ Approved'
                    : '✗ Rejected',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.deposit.status == PendingDepositStatus.approved
                      ? AppColors.success
                      : AppColors.error,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            )
          else if (_isActing)
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _approve,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Refund Requests List ──────────────────────────────────────────────────────

class _RefundRequestsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RefundRequestModel>>(
      stream: WalletService.watchAllRefundRequests(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        final requests = snap.data ?? [];
        if (requests.isEmpty) {
          return const _EmptyState(
            icon: Icons.check_circle_outline_rounded,
            message: 'No pending refunds',
            subtitle: 'All refund requests have been processed.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: requests.length,
          separatorBuilder: (_, index) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _RefundCard(request: requests[i]),
        );
      },
    );
  }
}

class _RefundCard extends StatefulWidget {
  const _RefundCard({required this.request});
  final RefundRequestModel request;

  @override
  State<_RefundCard> createState() => _RefundCardState();
}

class _RefundCardState extends State<_RefundCard> {
  bool _isActing = false;

  Future<void> _review() async {
    setState(() => _isActing = true);
    try {
      final adminUid = FirebaseAuth.instance.currentUser!.uid;
      await WalletService.reviewRefund(widget.request.id, adminUid);
      if (!mounted) return;
      setState(() => _isActing = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActing = false);
      _showError(e.toString());
    }
  }

  Future<void> _approve() async {
    setState(() => _isActing = true);
    try {
      final adminUid = FirebaseAuth.instance.currentUser!.uid;
      await WalletService.approveRefund(widget.request.id, adminUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Refund of ${WalletFormatters.currency(widget.request.amount)} approved.',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActing = false);
      _showError(e.toString());
    }
  }

  Future<void> _reject() async {
    final reason = await _showRejectDialog(context, 'Reject Refund');
    if (reason == null || !mounted) return;
    setState(() => _isActing = true);
    try {
      final adminUid = FirebaseAuth.instance.currentUser!.uid;
      await WalletService.rejectRefund(widget.request.id, adminUid, reason);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActing = false);
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRequested = widget.request.status == RefundRequestStatus.refundRequested;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                WalletFormatters.currency(widget.request.amount),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.terracotta.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.request.status.label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailRow(
            label: 'Order ID',
            value: widget.request.orderId.length >= 8
                ? '#${widget.request.orderId.substring(0, 8).toUpperCase()}'
                : '#${widget.request.orderId.toUpperCase()}',
            monospace: true,
          ),
          const SizedBox(height: 6),
          // User Name & UID
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance.collection('Users').doc(widget.request.userId).get(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();
              final name = (data?['name'] as String?)?.trim();
              final displayName = name == null || name.isEmpty ? 'Customer' : name;
              return _DetailRow(
                label: 'User',
                value: '$displayName (${widget.request.userId.substring(0, 5)}...)',
              );
            },
          ),
          const SizedBox(height: 6),
          _DetailRow(
            label: 'Requested',
            value: WalletFormatters.dateTime(widget.request.createdAt),
          ),
          if (widget.request.reason != null &&
              widget.request.reason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            _DetailRow(
              label: 'Reason',
              value: widget.request.reason!,
            ),
          ],
          const SizedBox(height: 18),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),
          // Actions
          if (widget.request.status == RefundRequestStatus.approved ||
              widget.request.status == RefundRequestStatus.credited ||
              widget.request.status == RefundRequestStatus.rejected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: (widget.request.status == RefundRequestStatus.approved ||
                        widget.request.status == RefundRequestStatus.credited)
                    ? AppColors.success.withValues(alpha: 0.08)
                    : AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                (widget.request.status == RefundRequestStatus.approved ||
                        widget.request.status == RefundRequestStatus.credited)
                    ? '✓ Approved & Credited'
                    : '✗ Rejected',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: (widget.request.status == RefundRequestStatus.approved ||
                          widget.request.status == RefundRequestStatus.credited)
                      ? AppColors.success
                      : AppColors.error,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            )
          else if (_isActing)
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
            )
          else if (isRequested)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _review,
                icon: const Icon(Icons.assignment_outlined, size: 18),
                label: const Text('Start Review'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _approve,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Approve & Credit'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

/// Shows a dialog asking the admin to enter a rejection reason.
/// Returns the reason string, or null if cancelled.
Future<String?> _showRejectDialog(BuildContext context, String title) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: AppColors.textPrimary,
        ),
      ),
      content: TextField(
        controller: controller,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Enter reason for rejection…',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(null),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final reason = controller.text.trim();
            if (reason.isNotEmpty) Navigator.of(ctx).pop(reason);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Reject'),
        ),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontFamily: monospace ? 'monospace' : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _GatewayBadge extends StatelessWidget {
  const _GatewayBadge({required this.gateway});
  final String gateway;

  @override
  Widget build(BuildContext context) {
    final isMock = gateway == 'mock';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isMock
            ? const Color(0xFFFFF3CD)
            : AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isMock ? 'MOCK' : 'RAZORPAY',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: isMock ? const Color(0xFF856404) : AppColors.success,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.subtitle,
  });

  final IconData icon;
  final String message;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: AppColors.success),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
