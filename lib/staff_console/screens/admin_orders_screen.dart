import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/services/api_client.dart';
import '../../user_console/services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../user_console/utils/order_status_utils.dart';

/// Re-themed auxiliary admin orders screen utilizing the design tokens of the Premium Organic system.
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  late final Future<bool> _adminFuture;
  final Set<String> _updatingOrderIds = <String>{};

  @override
  void initState() {
    super.initState();
    _adminFuture = AuthService.isCurrentUserAdmin();
  }

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
    return FutureBuilder<bool>(
      future: _adminFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.bg,
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        if (snapshot.data != true) {
          return const Scaffold(
            backgroundColor: AppColors.bg,
            body: Center(
              child: Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            title: const Text(
              'Manage Orders',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
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
                  final total = ((data['total'] ?? 0) as num).toInt();
                  final tokenNumber =
                      ((data['tokenNumber'] ?? 0) as num).toInt();
                  final isDelivered = status.toLowerCase() == 'delivered';
                  final isUpdating = _updatingOrderIds.contains(doc.id);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order ID: ${doc.id}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Token #$tokenNumber',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total: ₹$total',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Text(
                                'Status: ',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: getStatusColor(status),
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
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isDelivered || isUpdating
                                  ? null
                                  : () => _markDelivered(doc.id, status),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: isUpdating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      isDelivered
                                          ? 'Already Delivered'
                                          : 'Mark Delivered',
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
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
