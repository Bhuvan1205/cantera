import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../user_console/services/order_service.dart';
import '../../theme/app_colors.dart';
import '../widgets/staff_metric_pill.dart';
import '../widgets/staff_order_card.dart';

/// The orders tab of the Canteen Staff Terminal.
///
/// Features a real-time feed of active orders and completed orders for the day,
/// with status filter toggles and modular cards.
class StaffOrdersTab extends StatefulWidget {
  const StaffOrdersTab({
    super.key,
    required this.onOpenScanner,
  });

  final VoidCallback onOpenScanner;

  @override
  State<StaffOrdersTab> createState() => _StaffOrdersTabState();
}

class _StaffOrdersTabState extends State<StaffOrdersTab> {
  String _selectedFilter = 'placed'; // 'placed', 'preparing', 'ready_for_pickup', or 'delivered'
  String _selectedCounter = 'all'; // 'all', 'mess', 'bakery', 'beverages'

  Future<void> _showPinDialog(String orderId, String category) async {
    final pinController = TextEditingController();
    bool isVerifying = false;
    String? localError;

    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Enter Pickup PIN',
              style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Please ask the customer for their 4-digit PIN to complete the delivery.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    style: const TextStyle(fontSize: 20, letterSpacing: 4, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      counterText: '',
                      errorText: localError,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isVerifying ? null : () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                onPressed: isVerifying ? null : () async {
                  final pin = pinController.text.trim();
                  if (pin.length != 4) {
                    setDialogState(() => localError = 'PIN must be 4 digits');
                    return;
                  }
                  setDialogState(() {
                    isVerifying = true;
                    localError = null;
                  });
                  try {
                    await OrderService.verifyOtpViaBackend(
                      orderId: orderId,
                      counter: category,
                      otp: pin,
                    );
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop(true);
                  } catch (err) {
                    setDialogState(() {
                      isVerifying = false;
                      localError = err.toString().replaceFirst('Exception: ', '');
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: isVerifying 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                    : const Text('Verify', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        });
      },
    );

    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mess Order delivered successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day));

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('Orders')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          );
        }

        final allDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
            snapshot.data?.docs ?? []);

        // Calculate metrics using all today's orders in real time
        final placedCount = allDocs
            .where((doc) =>
                (doc.data()['status'] as String? ?? 'placed').toLowerCase() == 'placed')
            .length;
        final preparingCount = allDocs
            .where((doc) =>
                (doc.data()['status'] as String? ?? 'placed').toLowerCase() == 'preparing')
            .length;
        final readyCount = allDocs
            .where((doc) =>
                (doc.data()['status'] as String? ?? 'placed').toLowerCase() == 'ready_for_pickup')
            .length;
        final deliveredCount = allDocs
            .where((doc) =>
                (doc.data()['status'] as String? ?? 'placed').toLowerCase() == 'delivered')
            .length;

        // Dynamically filter orders based on selected tab and counter
        final docs = allDocs.where((doc) {
          final status = (doc.data()['status'] as String? ?? 'placed').toLowerCase();

          if (_selectedFilter == 'placed') {
            if (status != 'placed') return false;
          } else if (_selectedFilter == 'preparing') {
            if (status != 'preparing') return false;
          } else if (_selectedFilter == 'ready_for_pickup') {
            if (status != 'ready_for_pickup') return false;
          } else {
            if (status != 'delivered') return false;
          }

          if (_selectedCounter != 'all') {
            final catTokens = doc.data()['categoryTokens'] as Map<String, dynamic>?;
            if (catTokens == null || !catTokens.containsKey(_selectedCounter)) return false;

            final catStatus = (catTokens[_selectedCounter]['status'] as String? ?? 'placed').toLowerCase();
            if (_selectedFilter == 'placed' && catStatus != 'placed') return false;
            if (_selectedFilter == 'preparing' && catStatus != 'preparing') return false;
            if (_selectedFilter == 'ready_for_pickup' && catStatus != 'ready_for_pickup') return false;
            if (_selectedFilter == 'delivered' && catStatus != 'delivered') return false;
          }

          return true;
        }).toList();

        return ListView(
          padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.of(context).padding.bottom + 88),
          children: [
            // Top Section Indicator
            const Text(
              'REAL-TIME FEED',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 8),
            // Header Row: Title (Without the top right show active button)
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Incoming\nOrders',
                  style: TextStyle(
                    height: 1.05,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Subtitle Description
            const Text(
              'Monitor customer orders in real time. Coordinate preparation and hand over orders efficiently.',
              style: TextStyle(
                height: 1.5,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            // Status Metric Pills
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _selectedFilter = 'placed'),
                  child: Opacity(
                    opacity: _selectedFilter == 'placed' ? 1.0 : 0.6,
                    child: StaffMetricPill(
                      label: '$placedCount PLACED',
                      color: AppColors.error,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _selectedFilter = 'preparing'),
                  child: Opacity(
                    opacity: _selectedFilter == 'preparing' ? 1.0 : 0.6,
                    child: StaffMetricPill(
                      label: '$preparingCount PREPARING',
                      color: AppColors.warning,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _selectedFilter = 'ready_for_pickup'),
                  child: Opacity(
                    opacity: _selectedFilter == 'ready_for_pickup' ? 1.0 : 0.6,
                    child: StaffMetricPill(
                      label: '$readyCount READY FOR PICKUP',
                      color: AppColors.readyBrown,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _selectedFilter = 'delivered'),
                  child: Opacity(
                    opacity: _selectedFilter == 'delivered' ? 1.0 : 0.6,
                    child: StaffMetricPill(
                      label: '$deliveredCount DELIVERED',
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Section Filter Row
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildCounterChip('All Sections', 'all'),
                  const SizedBox(width: 8),
                  _buildCounterChip('Mess', 'mess'),
                  const SizedBox(width: 8),
                  _buildCounterChip('Continental', 'continental'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Order Cards List
            if (docs.isEmpty)
              _buildEmptyState()
            else
              ...docs.map(
                (doc) {
                  final data = doc.data();
                  VoidCallback? onTap;
                  
                  final catTokens = data['categoryTokens'] as Map<String, dynamic>?;
                  if (catTokens != null) {
                    String? targetCategory;
                    if (_selectedCounter != 'all' && catTokens.containsKey(_selectedCounter)) {
                      targetCategory = _selectedCounter;
                    } else {
                      targetCategory = catTokens.keys.firstWhere(
                        (k) => (catTokens[k]['status'] as String? ?? '').toLowerCase() == 'ready_for_pickup',
                        orElse: () => catTokens.keys.first,
                      );
                    }

                    if (catTokens.containsKey(targetCategory)) {
                      final tokenStatus = (catTokens[targetCategory]['status'] as String? ?? '').toLowerCase();
                      if (tokenStatus == 'ready_for_pickup') {
                        onTap = () => _showPinDialog(doc.id, targetCategory!);
                      }
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: StaffOrderCard(
                      orderId: doc.id,
                      data: data,
                      onTap: onTap,
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 60),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 48,
            color: AppColors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 14),
          const Text(
            'No Active Orders',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'New tickets will show up here automatically.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterChip(String label, String value) {
    final isSelected = _selectedCounter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedCounter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
