import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../utils/app_keys.dart';
import '../utils/order_status_utils.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/status_badge.dart';
import 'qr_screen.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class OrderItemData {
  final String name;
  final String quantityLabel;
  final String? description;

  const OrderItemData({
    required this.name,
    required this.quantityLabel,
    this.description,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.tokenNumber,
    required this.items,
    required this.total,
    this.estimatedTime,
    this.onContactSupport,
    this.onHomeTap,
    this.onCartTap,
    this.onRefundRequest,
    this.isRefundPending = false,
  });

  final String orderId;
  final String orderNumber;
  final String status;
  final int tokenNumber;
  final List<OrderItemData> items;
  final int total;
  final String? estimatedTime;
  final VoidCallback? onContactSupport;
  final VoidCallback? onHomeTap;
  final VoidCallback? onCartTap;

  /// Called when the user confirms a refund request.
  /// Only provided when [status] == 'placed'.
  final Future<void> Function()? onRefundRequest;

  /// True when a refund request is already pending for this order.
  final bool isRefundPending;

  bool get _isDelivered => status.toLowerCase() == 'delivered';
  bool get _isCancelled => status.toLowerCase() == 'cancelled';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(context),
      bottomNavigationBar: AppBottomNav(
        selectedTab: NavTab.orders,
        onHomeTap: onHomeTap,
        onCartTap: onCartTap,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _OrderSummaryCard(
              key: AppKeys.orderDetailSummaryCard,
              items: items,
              total: total,
            ),
            const SizedBox(height: 20),
            _QrButton(
              key: AppKeys.orderDetailQrButton,
              isDelivered: _isDelivered,
              isCancelled: _isCancelled,
              onTap: (_isDelivered || _isCancelled)
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderQrScreen(
                            orderId: orderId,
                          ),
                        ),
                      ),
            ),
            const SizedBox(height: 14),
            // ── Refund Button ────────────────────────────────────────────────
            _RefundButton(
              key: AppKeys.orderRefundButton,
              status: status,
              isRefundPending: isRefundPending,
              onRefundRequest: onRefundRequest,
            ),
            const SizedBox(height: 30),
            _SupportFooter(onTap: onContactSupport),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      title: const Text('Canteen'),
    );
  }

  Widget _buildHeader() {
    final statusColor = getStatusColor(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Current Order',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          orderNumber,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            // Uses shared StatusBadge — full variant (dot + label)
            StatusBadge(label: status, color: statusColor),
            const Spacer(),
            Text(
              'Token #$tokenNumber',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Total: ₹$total',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

/// Card showing the itemized order lines and total.
class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({
    super.key,
    required this.items,
    required this.total,
  });

  final List<OrderItemData> items;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 20),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, _) => Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              height: 1,
              color: AppColors.border,
            ),
            itemBuilder: (_, index) => _OrderItemRow(
              // ValueKey for correct list reconciliation in tests + inspector
              key: ValueKey('order_item_$index'),
              item: items[index],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 18),
            height: 1,
            color: AppColors.border,
          ),
          Row(
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '₹$total',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({super.key, required this.item});
  final OrderItemData item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (item.description != null) ...[
                const SizedBox(height: 3),
                Text(
                  item.description!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 14),
        Text(
          item.quantityLabel,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _QrButton extends StatelessWidget {
  const _QrButton({
    super.key,
    required this.isDelivered,
    required this.isCancelled,
    this.onTap,
  });

  final bool isDelivered;
  final bool isCancelled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDisabled = isDelivered || isCancelled;
    final titleText = isCancelled 
        ? 'Order Refunded / Cancelled' 
        : isDelivered 
            ? 'Order Delivered'
            : 'Display Pickup QR Code';

    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isDisabled
            ? AppColors.cardBg
            : AppColors.primary,
        foregroundColor: isDisabled
            ? AppColors.textMuted
            : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        minimumSize: const Size(double.infinity, 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: isDisabled ? const BorderSide(color: AppColors.border) : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCancelled 
                      ? 'REFUNDED' 
                      : 'PICKUP IDENTIFICATION',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.4,
                    color: isDisabled ? AppColors.textMuted : const Color(0xFFAAC4B6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  titleText,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Icon(
            isCancelled ? Icons.cancel_outlined : Icons.qr_code_2_rounded, 
            size: 32,
            color: isDisabled ? AppColors.textMuted : null,
          ),
        ],
      ),
    );
  }
}


class _SupportFooter extends StatelessWidget {
  const _SupportFooter({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Text(
            'Something wrong with your order?',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onTap,
            child: const Text(
              'Contact Canteen Support',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Refund Button ─────────────────────────────────────────────────────────────

/// Shows a refund request button when the order is in 'placed' status.
///
/// - Hidden when status is anything other than 'placed' or 'refund_pending'.
/// - Shows a "Refund Pending" badge when [isRefundPending] is true.
/// - Enabled only when status == 'placed' AND no pending refund exists.
class _RefundButton extends StatefulWidget {
  const _RefundButton({
    super.key,
    required this.status,
    required this.isRefundPending,
    this.onRefundRequest,
  });

  final String status;
  final bool isRefundPending;
  final Future<void> Function()? onRefundRequest;

  @override
  State<_RefundButton> createState() => _RefundButtonState();
}

class _RefundButtonState extends State<_RefundButton> {
  bool _isRequesting = false;

  bool get _isPlaced => widget.status.toLowerCase() == 'placed';
  bool get _isRefundPending =>
      widget.isRefundPending ||
      widget.status.toLowerCase() == 'refund_pending';

  /// Refund button is visible only for 'placed' or 'refund_pending' orders.
  bool get _isVisible => _isPlaced || _isRefundPending;

  Future<void> _handleRefundRequest() async {
    // Confirm dialog before submitting.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Request Refund?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'This will cancel your order and request a refund to your wallet. '
          'The refund will be processed by the canteen admin.',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Keep Order',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Request Refund'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isRequesting = true);
    try {
      await widget.onRefundRequest?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Refund requested — pending admin review.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Refund request failed: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    if (_isRefundPending) {
      // Show informational badge — no action.
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFD966)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_top_rounded, color: Color(0xFF856404), size: 18),
            SizedBox(width: 8),
            Text(
              'Refund Pending Admin Review',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF856404),
              ),
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: _isRequesting ? null : _handleRefundRequest,
      icon: _isRequesting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.error,
              ),
            )
          : const Icon(Icons.undo_rounded, size: 18),
      label: Text(_isRequesting ? 'Submitting…' : 'Request Refund'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: const BorderSide(color: AppColors.error),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
