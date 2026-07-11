import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../utils/app_keys.dart';
import '../utils/order_status_utils.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/status_badge.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class OrderHistoryItem {
  final String id;
  final String orderNumber;
  final String title;
  final String dateTime;
  final int total;
  final int tokenNumber;
  final String status;
  final String? imageUrl;
  final String? actionLabel;

  const OrderHistoryItem({
    required this.id,
    required this.orderNumber,
    required this.title,
    required this.dateTime,
    required this.total,
    required this.tokenNumber,
    required this.status,
    this.imageUrl,
    this.actionLabel,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({
    super.key,
    required this.orders,
    required this.onTap,
    this.isLoading = false,
    this.onHomeTap,
    this.onQueueTap,
    this.onCartNavTap,
    this.onRefresh,
  });

  final List<OrderHistoryItem> orders;
  final void Function(OrderHistoryItem order) onTap;
  final bool isLoading;
  final VoidCallback? onHomeTap;
  final VoidCallback? onQueueTap;
  final VoidCallback? onCartNavTap;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    Widget bodyContent = SafeArea(
      child: isLoading
          ? const Center(
              key: AppKeys.loadingIndicator,
              child: CircularProgressIndicator(),
            )
          : orders.isEmpty
              ? Stack(
                  children: [
                    ListView(physics: const AlwaysScrollableScrollPhysics()),
                    const _EmptyOrders(),
                  ],
                )
              : ListView.builder(
                  key: AppKeys.orderHistoryList,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                  itemCount: orders.length + 1, // +1 for header
                  itemBuilder: (context, index) {
                    if (index == 0) return const _HeaderSection();
                    final order = orders[index - 1];
                    return Padding(
                      // ValueKey ensures Flutter tracks each card by order ID,
                      // not by list position — critical for animated updates.
                      key: ValueKey('order_card_${order.id}'),
                      padding: const EdgeInsets.only(bottom: 18),
                      child: OrderHistoryCard(
                        order: order,
                        onTap: () => onTap(order),
                      ),
                    );
                  },
                ),
    );

    if (onRefresh != null) {
      bodyContent = RefreshIndicator(
        onRefresh: onRefresh!,
        color: AppColors.primary,
        backgroundColor: AppColors.cardBg,
        child: bodyContent,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(context),
      bottomNavigationBar: AppBottomNav(
        selectedTab: NavTab.orders,
        onHomeTap: onHomeTap,
        onQueueTap: onQueueTap,
        onCartTap: onCartNavTap,
      ),
      body: bodyContent,
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
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Past Activity',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Order History',
            style: TextStyle(
              fontSize: 32,
              height: 1.05,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'A record of your recent canteen orders.',
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable order card shown in the history list.
///
/// Keyed externally via `ValueKey('order_card_${order.id}')`.
class OrderHistoryCard extends StatelessWidget {
  const OrderHistoryCard({
    super.key,
    required this.order,
    required this.onTap,
  });

  final OrderHistoryItem order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = getStatusColor(order.status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Uses shared StatusBadge — compact variant for cards
                        StatusBadge(
                          label: order.status,
                          color: statusColor,
                          compact: true,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            order.orderNumber,
                            style: const TextStyle(
                              fontSize: 12,
                              letterSpacing: 0.8,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      order.title,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      order.dateTime,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          'Token #${order.tokenNumber}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '₹${order.total}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (order.actionLabel != null) ...[
                      const SizedBox(height: 12),
                      _ReorderLabel(label: order.actionLabel!),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _OrderThumbnail(imageUrl: order.imageUrl),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReorderLabel extends StatelessWidget {
  const _ReorderLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.refresh_rounded, size: 16, color: AppColors.accent),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}

class _OrderThumbnail extends StatelessWidget {
  const _OrderThumbnail({this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.border,
        image: (imageUrl != null && imageUrl!.isNotEmpty)
            ? DecorationImage(
                image: (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://'))
                    ? NetworkImage(imageUrl!) as ImageProvider
                    : AssetImage(imageUrl!) as ImageProvider,
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: (imageUrl == null || imageUrl!.isEmpty)
          ? const Icon(
              Icons.receipt_long_rounded,
              size: 28,
              color: AppColors.textMuted,
            )
          : null,
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: AppKeys.emptyStateView,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'No orders yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your order history will appear here.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
