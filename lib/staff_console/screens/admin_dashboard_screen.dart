import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../user_console/screens/qr_scanner_screen.dart';
import '../../user_console/services/auth_service.dart';
import '../../user_console/services/order_service.dart';
import '../../theme/app_colors.dart';
import '../tabs/staff_inventory_tab.dart';
import '../tabs/staff_orders_tab.dart';
import '../tabs/staff_queue_tab.dart';
import '../tabs/staff_settings_tab.dart';
import '../tabs/staff_wallet_tab.dart';
import '../widgets/staff_bottom_nav.dart';

/// The core host and shell for the Canteen Staff Terminal.
///
/// Handles permissions authentication, manages active bottom tab states, and coordinates
/// the operational scanner dialogs.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final Future<bool> _adminFuture;
  int _currentIndex = 0;
  bool _newOrderAlerts = true;
  bool _stockWarnings = true;
  bool _dailySummary = false;

  @override
  void initState() {
    super.initState();
    _adminFuture = AuthService.isCurrentUserAdmin();
  }

  /// Routes every admin QR scan through [OrderService.handleQrScan] which
  /// handles the new subcollection schema, old categoryTokens, and mess OTP flow.
  Future<String> _handleDeliveredScan(String scannedValue) async {
    return await OrderService.handleQrScan(scannedValue);
  }

  Future<void> _openScanner() async {
    final scannedData = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(
          isAdmin: true,
          markAsDelivered: _handleDeliveredScan,
        ),
      ),
    );

    if (scannedData != null && mounted) {
      final parts = scannedData.split('||');
      final scannedValue = parts[0];
      final result = parts.length > 1 ? parts[1] : 'delivered';

      String actualOrderId = scannedValue;
      if (scannedValue.contains('::')) {
        actualOrderId = scannedValue.split('::').first;
      }

      final doc = await FirebaseFirestore.instance.collection('Orders').doc(actualOrderId).get();
      if (!doc.exists) return;
      final data = doc.data()!;
      final items = _orderItemsFrom(data['items']);
      final userId = data['userId'] as String?;
      String userName = 'Customer';
      if (userId != null && userId.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();
        userName = (userDoc.data()?['name'] as String?)?.trim() ?? 'Customer';
      }

      if (!mounted) return;

      final isQueued = result == 'mess_preparing';

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border, width: 1.5),
          ),
          title: Text(
            isQueued ? 'Token Queued' : 'Order Handover',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: -0.5,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer: ${_titleCase(userName)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isQueued ? 'Items queued for preparation:' : 'Items to hand over:',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primary),
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
              )),
              const SizedBox(height: 10),
              Text(
                isQueued ? 'Status automatically updated to Preparing.' : 'Status automatically updated to Delivered.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                elevation: 0,
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ],
        ),
      );
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
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
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
            centerTitle: true,
            title: const Text(
              'CANTEEN STAFF',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: IconButton(
                  onPressed: _openScanner,
                  icon: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppColors.primary,
                    size: 26,
                  ),
                  tooltip: 'Scan Order Token',
                ),
              ),
            ],
          ),
          extendBody: true, // Flow content under staff bottom nav
          body: IndexedStack(
            index: _currentIndex,
            children: [
              StaffOrdersTab(onOpenScanner: _openScanner),
              const StaffInventoryTab(),
              const StaffQueueTab(),
              const StaffWalletTab(),
              StaffSettingsTab(
                newOrderAlerts: _newOrderAlerts,
                stockWarnings: _stockWarnings,
                dailySummary: _dailySummary,
                onNewOrderAlertsChanged: (value) {
                  setState(() {
                    _newOrderAlerts = value;
                  });
                },
                onStockWarningsChanged: (value) {
                  setState(() {
                    _stockWarnings = value;
                  });
                },
                onDailySummaryChanged: (value) {
                  setState(() {
                    _dailySummary = value;
                  });
                },
              ),
            ],
          ),
          bottomNavigationBar: StaffBottomNav(
            currentIndex: _currentIndex,
            onChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            onScanTap: _openScanner,
          ),
        );
      },
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

  String _titleCase(String value) {
    return value.split(' ').map((word) {
      if (word.isEmpty) return word;
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }
}
