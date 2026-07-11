import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../utils/app_keys.dart';

/// Which tab is currently active in the bottom navigation bar.
enum NavTab { home, cart, orders, queue }

/// Shared bottom navigation bar used across all user-facing screens.
///
/// **Usage:**
/// ```dart
/// Scaffold(
///   bottomNavigationBar: AppBottomNav(
///     selectedTab: NavTab.cart,
///     onHomeTap: () { ... },
///     onOrdersTap: () { ... },
///     onQueueTap: () { ... },
///   ),
/// )
/// ```
///
/// The [selectedTab] parameter controls which item is highlighted.
/// Unspecified tap callbacks default to `null` (item is non-interactive).
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.selectedTab,
    this.onHomeTap,
    this.onOrdersTap,
    this.onQueueTap,
    this.onCartTap,
  });

  final NavTab selectedTab;
  final VoidCallback? onHomeTap;
  final VoidCallback? onOrdersTap;
  final VoidCallback? onQueueTap;
  final VoidCallback? onCartTap;

  @override
  Widget build(BuildContext context) {
    // Use viewPadding (not padding) because extendBody:true zeros out
    // MediaQuery.padding.bottom on the Scaffold level. viewPadding always
    // returns the true system nav bar / home-indicator height.
    final double systemNavInset = MediaQuery.viewPaddingOf(context).bottom;
    final double bottomMargin = systemNavInset > 0 ? systemNavInset + 8 : 20;

    return Container(
      margin: EdgeInsets.fromLTRB(18, 0, 18, bottomMargin),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            key: AppKeys.navHomeTab,
            icon: Icons.home_filled,
            label: 'Home',
            selected: selectedTab == NavTab.home,
            onTap: onHomeTap,
          ),
          _NavItem(
            key: AppKeys.navCartTab,
            icon: Icons.shopping_cart_rounded,
            label: 'Cart',
            selected: selectedTab == NavTab.cart,
            onTap: onCartTap,
          ),
          _NavItem(
            key: AppKeys.navOrdersTab,
            icon: Icons.receipt_long_rounded,
            label: 'Orders',
            selected: selectedTab == NavTab.orders,
            onTap: onOrdersTap,
          ),
          _NavItem(
            icon: Icons.view_list_rounded,
            label: 'Queue',
            selected: selectedTab == NavTab.queue,
            onTap: onQueueTap,
          ),
        ],
      ),
    );
  }
}

/// Single tab item inside [AppBottomNav].
///
/// When [selected] is true, shows an expanded pill with label + icon.
/// When [selected] is false, shows only the icon in a compact touch target.
class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 20 : 12,
          vertical: selected ? 10 : 6,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : AppColors.textMuted,
              size: 22,
            ),
            if (selected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
