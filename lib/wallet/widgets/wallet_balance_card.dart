import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../models/wallet_model.dart';
import '../utils/wallet_formatters.dart';

/// Displays the user's current wallet balance with a premium gradient card.
///
/// Used on [WalletScreen] as the hero element.
/// Optionally shows a loading shimmer while the wallet is being fetched.
class WalletBalanceCard extends StatelessWidget {
  const WalletBalanceCard({
    super.key,
    this.wallet,
    this.isLoading = false,
    this.onAddMoney,
  });

  final WalletModel? wallet;
  final bool isLoading;

  /// Callback when the "Add Money" button is tapped.
  final VoidCallback? onAddMoney;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F382B), Color(0xFF1A5C42)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Label row ────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Cantora Wallet',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xAAFFFFFF),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Balance amount ────────────────────────────────────────────────
          if (isLoading)
            _BalanceShimmer()
          else
            Text(
              wallet == null
                  ? '₹0'
                  : WalletFormatters.currency(wallet!.balance),
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -1,
                height: 1,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            'Available Balance',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 28),

          // ── Stats row ─────────────────────────────────────────────────────
          if (!isLoading && wallet != null) ...[
            Row(
              children: [
                _StatChip(
                  label: 'Added',
                  value: WalletFormatters.currency(wallet!.totalAdded),
                  icon: Icons.arrow_downward_rounded,
                  color: const Color(0xFF4CAF50),
                ),
                const SizedBox(width: 12),
                _StatChip(
                  label: 'Spent',
                  value: WalletFormatters.currency(wallet!.totalSpent),
                  icon: Icons.arrow_upward_rounded,
                  color: AppColors.terracotta,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ] else
            const SizedBox(height: 24),

          // ── Add Money button ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onAddMoney,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Add Money'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceShimmer extends StatefulWidget {
  @override
  State<_BalanceShimmer> createState() => _BalanceShimmerState();
}

class _BalanceShimmerState extends State<_BalanceShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Container(
        width: 160,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _anim.value),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
