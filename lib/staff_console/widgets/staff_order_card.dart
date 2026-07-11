import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../user_console/utils/order_status_utils.dart';
import '../../user_console/widgets/status_badge.dart';

/// A premium card to display incoming order details to the canteen staff.
class StaffOrderCard extends StatelessWidget {
  const StaffOrderCard({
    super.key,
    required this.orderId,
    required this.data,
    this.onTap,
  });

  final String orderId;
  final Map<String, dynamic> data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shortId = orderId.length > 4 ? orderId.substring(0, 4).toUpperCase() : orderId.toUpperCase();
    final orderNumber = '#$shortId';
    final items = _orderItemsFrom(data['items']);
    final orderStatus = (data['status'] as String? ?? 'placed');
    final paymentStatus = _paymentStatusFrom(data);
    final total = (data['total'] as num?)?.toInt() ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Order Main Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ORDER $orderNumber',
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 10),
                // Customer Name (Asynchronous lookup)
                _CustomerName(userId: data['userId'] as String?),
                const SizedBox(height: 14),
                // List of Items
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 14),
                // Payment Info
                const Text(
                  'PAYMENT STATUS',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  paymentStatus,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right Column: Status & Amount Paid
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatusBadge(
                label: orderStatus,
                color: getStatusColor(orderStatus),
                compact: true,
              ),
              const SizedBox(height: 40),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'AMOUNT PAID',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹$total',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
        ),
      ),
    );
  }

  List<String> _orderItemsFrom(dynamic rawItems) {
    if (rawItems is! List) return const [];
    return rawItems
        .whereType<Map>()
        .map((item) {
          final name = item['name'] as String? ?? 'Item';
          final quantity = ((item['quantity'] ?? 1) as num).toInt();
          return quantity > 1 ? '$name x$quantity' : name;
        })
        .toList();
  }

  String _paymentStatusFrom(Map<String, dynamic> data) {
    final paymentStatus = (data['paymentStatus'] as String?)?.trim();
    if (paymentStatus != null && paymentStatus.isNotEmpty) return paymentStatus;

    final paymentMethod = (data['paymentMethod'] as String?)?.trim();
    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      return 'Paid via $paymentMethod';
    }

    return 'Paid in App';
  }
}

class _CustomerName extends StatelessWidget {
  const _CustomerName({required this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context) {
    if (userId == null || userId!.isEmpty) {
      return const Text(
        'Guest Customer',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('Users').doc(userId).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final name = (data?['name'] as String?)?.trim();

        return Text(
          name == null || name.isEmpty ? 'Customer' : _titleCase(name),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        );
      },
    );
  }

  String _titleCase(String value) {
    return value.split(' ').map((word) {
      if (word.isEmpty) return word;
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }
}
