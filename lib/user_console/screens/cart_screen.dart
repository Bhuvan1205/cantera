import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../wallet/services/wallet_service.dart';
import '../../wallet/widgets/payment_method_selector.dart';
import '../utils/app_keys.dart';
import '../widgets/app_bottom_nav.dart';
import '../models/group_order_model.dart';

// ── Data model ──────────────────────────────────────────────────────────────

class CartItemData {
  final String id;
  final String name;
  final int price;
  final int quantity;
  final String? description;
  final String? imageUrl;

  const CartItemData({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.description,
    this.imageUrl,
  });

  factory CartItemData.fromCartEntry(String id, Map<String, dynamic> data) {
    return CartItemData(
      id: id,
      name: data['name'] as String,
      price: (data['price'] as num).toInt(),
      quantity: data['quantity'] as int,
      description: data['description'] as String?,
      imageUrl: data['imageUrl'] as String?,
    );
  }

  double get lineTotal => price * quantity.toDouble();
}

// ── Screen ───────────────────────────────────────────────────────────────────

class ReviewOrderScreen extends StatefulWidget {
  const ReviewOrderScreen({
    super.key,
    required this.cartItems,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
    required this.onPlaceOrder,
    this.cartItemsBuilder,
    this.ecoFee = 0.0,
    this.isPlacingOrder = false,
    this.onHomeTap,
    this.onOrdersTap,
    this.onQueueTap,
    this.groupOrder,
  });

  final List<CartItemData> cartItems;

  /// Optional live builder — called on each rebuild to get the latest cart.
  /// Preferred over [cartItems] when the cart is mutable during the session.
  final List<CartItemData> Function()? cartItemsBuilder;

  final void Function(String id) onDecrease;
  final void Function(String id) onIncrease;
  final void Function(String id) onRemove;

  /// Called when the user taps Place Order.
  /// Receives the [BuildContext] and the chosen [OrderPaymentMethod].
  final Future<void> Function(BuildContext context, OrderPaymentMethod method) onPlaceOrder;
  final double ecoFee;
  final bool isPlacingOrder;
  final VoidCallback? onHomeTap;
  final VoidCallback? onOrdersTap;
  final VoidCallback? onQueueTap;
  /// When supplied, this existing review screen presents group order context
  /// instead of suggesting an independent checkout.
  final GroupOrder? groupOrder;

  @override
  State<ReviewOrderScreen> createState() => _ReviewOrderScreenState();
}

class _ReviewOrderScreenState extends State<ReviewOrderScreen> {
  List<CartItemData> get _items =>
      widget.cartItemsBuilder?.call() ?? widget.cartItems;

  OrderPaymentMethod _paymentMethod = OrderPaymentMethod.wallet;
  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  double get _subtotal => _items.fold(0, (sum, i) => sum + i.lineTotal);
  double get _total => _subtotal + widget.ecoFee;

  void _refresh(VoidCallback fn) {
    fn();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(context),
      bottomNavigationBar: AppBottomNav(
        selectedTab: NavTab.cart,
        onHomeTap: widget.onHomeTap,
        onOrdersTap: widget.onOrdersTap,
        onQueueTap: widget.onQueueTap,
      ),
      body: SafeArea(
        child: _items.isEmpty
            ? const _EmptyCart()
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                      children: [
                        _buildHeadline(),
                        const SizedBox(height: 28),
                        _buildItemList(),
                        const SizedBox(height: 32),
                        _buildSummaryCard(context),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
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

  Widget _buildHeadline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review Order',
          style: TextStyle(
            fontSize: 32,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.groupOrder?.isActive == true
              ? 'Group ${widget.groupOrder!.groupCode} · ${widget.groupOrder!.status}'
              : '${_items.length} item${_items.length == 1 ? '' : 's'} in your tray',
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildItemList() {
    return ListView.separated(
      key: AppKeys.cartItemList,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      separatorBuilder: (_, _) => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        height: 1,
        color: AppColors.border,
      ),
      itemBuilder: (context, index) {
        final item = _items[index];
        return CartItemTile(
          // ValueKey ensures Flutter correctly reconciles items when the list
          // changes (e.g. quantity update or removal).
          key: ValueKey('cart_tile_${item.id}'),
          item: item,
          onDecrease: () => _refresh(() => widget.onDecrease(item.id)),
          onIncrease: () => _refresh(() => widget.onIncrease(item.id)),
          onDelete: () => _refresh(() => widget.onRemove(item.id)),
          readOnly: widget.groupOrder != null,
        );
      },
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.summaryCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          _SummaryRow(label: 'Subtotal', value: '₹${_subtotal.toStringAsFixed(2)}'),
          if (widget.ecoFee > 0) ...[
            const SizedBox(height: 16),
            _EcoFeeRow(ecoFee: widget.ecoFee),
          ],
          Container(
            margin: const EdgeInsets.symmetric(vertical: 20),
            height: 1,
            color: AppColors.border,
          ),
          _SummaryRow(
            label: 'Total',
            value: '₹${_total.toStringAsFixed(2)}',
            isBold: true,
          ),
          const SizedBox(height: 28),
          // ── Payment method selector ────────────────────────────────────────
          PaymentMethodSelector(
            key: AppKeys.paymentMethodSelector,
            userId: _userId,
            orderTotal: _total,
            onMethodChanged: (method) => setState(() => _paymentMethod = method),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              key: AppKeys.cartPlaceOrderButton,
              onPressed: widget.isPlacingOrder
                  ? null
                  : () => widget.onPlaceOrder(context, _paymentMethod),
              child: widget.isPlacingOrder
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Place Order'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cart item tile ────────────────────────────────────────────────────────────

/// A single row in the cart list showing image, name, price, and qty controls.
///
/// Keyed externally via `ValueKey('cart_tile_${item.id}')` for list diffing.
class CartItemTile extends StatelessWidget {
  const CartItemTile({
    super.key,
    required this.item,
    required this.onDecrease,
    required this.onIncrease,
    required this.onDelete,
    this.readOnly = false,
  });

  final CartItemData item;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onDelete;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ItemThumbnail(imageUrl: item.imageUrl),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (!readOnly)
                      IconButton(
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
                if (item.description != null &&
                    item.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '₹${item.price}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (readOnly)
                      Text(
                        'x${item.quantity}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      )
                    else
                      _QtyControl(
                        quantity: item.quantity,
                        onDecrease: onDecrease,
                        onIncrease: onIncrease,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ItemThumbnail extends StatelessWidget {
  const _ItemThumbnail({this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
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
          ? const Icon(Icons.fastfood_rounded, size: 32, color: AppColors.textMuted)
          : null,
    );
  }
}

class _QtyControl extends StatelessWidget {
  const _QtyControl({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QtyButton(
            icon: Icons.remove_rounded,
            iconColor: AppColors.accent,
            filled: false,
            onTap: onDecrease,
          ),
          SizedBox(
            width: 32,
            child: Center(
              child: Text(
                '$quantity',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          _QtyButton(
            icon: Icons.add_rounded,
            iconColor: Colors.white,
            filled: true,
            onTap: onIncrease,
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({
    required this.icon,
    required this.iconColor,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 18 : 15,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: isBold ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 20 : 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _EcoFeeRow extends StatelessWidget {
  const _EcoFeeRow({required this.ecoFee});
  final double ecoFee;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.eco_rounded, size: 16, color: AppColors.success),
        const SizedBox(width: 6),
        const Text(
          'Eco Fee',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const Spacer(),
        Text(
          '+₹${ecoFee.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

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
              Icons.shopping_cart_rounded,
              size: 40,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add items from the menu to get started.',
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
