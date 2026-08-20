import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/services/api_client.dart';
import '../../theme/app_colors.dart';
import '../widgets/staff_order_card.dart';

/// Re-themed auxiliary admin orders screen utilizing the design tokens of the Premium Organic system.
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final Set<String> _updatingOrderIds = <String>{};

  Future<void> _markDelivered(String orderId, String status) async {
    if (status.toLowerCase() == 'delivered' ||
        _updatingOrderIds.contains(orderId)) {
      return;
    }

    setState(() {
      _updatingOrderIds.add(orderId);
    });

    try {
      await ApiClient.instance.patch('/api/orders/$orderId/status', body: {
        'status': 'delivered',
      });
    } finally {
      if (mounted) {
        setState(() {
          _updatingOrderIds.remove(orderId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: true,
        title: const Text('Manage Orders'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('Orders')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, orderSnapshot) {
          if (orderSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (orderSnapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${orderSnapshot.error}',
                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
              ),
            );
          }

          final docs = orderSnapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No orders found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final status = (data['status'] as String? ?? 'placed');
              final isDelivered = status.toLowerCase() == 'delivered';
              final isUpdating = _updatingOrderIds.contains(doc.id);

              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      children: [
                        StaffOrderCard(
                          orderId: doc.id,
                          data: data,
                        ),
                        if (isUpdating)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.bg.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Per-category token status
                    Builder(builder: (context) {
                      final categoryTokens =
                          data['categoryTokens'] as Map<String, dynamic>?;
                      if (categoryTokens == null ||
                          categoryTokens.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      final sortedCats = categoryTokens.keys.toList()
                        ..sort();
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.border, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SECTION TOKENS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...sortedCats.map((cat) {
                                final catData = categoryTokens[cat]
                                    as Map<String, dynamic>;
                                final catStatus = (catData['status']
                                        as String? ??
                                    'placed');
                                final catToken = ((catData[
                                            'tokenNumber'] ??
                                        0) as num)
                                    .toInt();
                                final isDone = catStatus.toLowerCase() ==
                                    'delivered';
                                final displayName =
                                    _categoryDisplayName(cat);
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isDone
                                            ? Icons.check_circle_rounded
                                            : Icons.radio_button_unchecked_rounded,
                                        size: 16,
                                        color: isDone
                                            ? AppColors.success
                                            : AppColors.textMuted,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$displayName  #$catToken',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isDone
                                              ? AppColors.success
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        isDone
                                            ? 'Delivered'
                                            : 'Pending',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isDone
                                              ? AppColors.success
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: isDelivered || isUpdating
                          ? null
                          : () => _markDelivered(doc.id, status),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                      ),
                      child: isUpdating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isDelivered ? 'Already Delivered' : 'Mark Delivered',
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

String _categoryDisplayName(String cat) {
  switch (cat) {
    case 'bakery':
      return 'Bakery';
    case 'mess':
      return 'Mess';
    case 'beverages':
      return 'Beverages';
    default:
      return cat[0].toUpperCase() + cat.substring(1);
  }
}
