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

  bool get _isDelivered => status.toLowerCase() == 'delivered';

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
              onTap: _isDelivered
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
  const _QrButton({super.key, required this.isDelivered, this.onTap});

  final bool isDelivered;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isDelivered
            ? AppColors.primary.withValues(alpha: 0.35)
            : AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        minimumSize: const Size(double.infinity, 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PICKUP IDENTIFICATION',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.4,
                    color: Color(0xFFAAC4B6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Display Pickup QR Code',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Icon(Icons.qr_code_2_rounded, size: 32),
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
