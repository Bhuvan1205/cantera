import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// A premium, organic bottom navigation bar designed for the Canteen Staff Terminal.
///
/// Contains three tabs: **ORDERS**, **INVENTORY**, and **SETTINGS**.
class StaffBottomNav extends StatelessWidget {
  const StaffBottomNav({
    super.key,
    required this.currentIndex,
    required this.onChanged,
    required this.onScanTap,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onScanTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Tab 0: Orders
            _buildTab(
              index: 0,
              icon: Icons.restaurant_menu_rounded,
              label: 'ORDERS',
            ),
            // Tab 1: Inventory
            _buildTab(
              index: 1,
              icon: Icons.inventory_2_rounded,
              label: 'INVENTORY',
            ),
            // Tab 2: Queue
            _buildTab(
              index: 2,
              icon: Icons.view_list_rounded,
              label: 'QUEUE',
            ),
            // Quick Action: Scan
            _buildScanAction(),
            // Tab 3: Wallet
            _buildTab(
              index: 3,
              icon: Icons.account_balance_wallet_rounded,
              label: 'WALLET',
            ),
            // Tab 4: Settings
            _buildTab(
              index: 4,
              icon: Icons.settings_rounded,
              label: 'SETTINGS',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanAction() {
    return Expanded(
      child: GestureDetector(
        onTap: onScanTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.12),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.qr_code_scanner_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(height: 4),
              const Text(
                'SCAN',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.summaryCard : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0.5,
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
