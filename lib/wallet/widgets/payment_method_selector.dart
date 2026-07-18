import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../models/wallet_model.dart';
import '../services/wallet_service.dart';
import '../utils/wallet_formatters.dart';

/// Payment method selection widget shown above the Place Order button in the cart.
///
/// Lets the user choose between:
///  - Wallet Credits (disabled if insufficient balance or wallet unavailable)
///  - Direct Payment (UPI / Card — future gateway integration)
///
/// Reports the chosen [OrderPaymentMethod] via [onMethodChanged].
class PaymentMethodSelector extends StatefulWidget {
  const PaymentMethodSelector({
    super.key,
    required this.userId,
    required this.orderTotal,
    required this.onMethodChanged,
    this.initialMethod = OrderPaymentMethod.wallet,
  });

  /// Firebase Auth UID of the logged-in user.
  final String userId;

  /// The total amount required to pay for the order in ₹.
  final double orderTotal;

  /// Called whenever the user switches payment method.
  final void Function(OrderPaymentMethod method) onMethodChanged;

  /// Which method is pre-selected (defaults to wallet).
  final OrderPaymentMethod initialMethod;

  @override
  State<PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends State<PaymentMethodSelector> {
  late OrderPaymentMethod _selected;
  WalletModel? _wallet;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialMethod;
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    try {
      final wallet = await WalletService.getWallet(widget.userId);
      if (!mounted) return;
      setState(() {
        _wallet = wallet;
        _loading = false;
        // Auto-switch to direct payment if wallet is insufficient.
        if (!_walletSufficient) {
          _selected = OrderPaymentMethod.directPayment;
          widget.onMethodChanged(_selected);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _selected = OrderPaymentMethod.directPayment;
        widget.onMethodChanged(_selected);
      });
    }
  }

  bool get _walletSufficient =>
      _wallet != null && _wallet!.hasSufficientBalance(widget.orderTotal);

  void _select(OrderPaymentMethod method) {
    if (method == OrderPaymentMethod.wallet && !_walletSufficient) return;
    setState(() => _selected = method);
    widget.onMethodChanged(method);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _SelectorShimmer();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PAYMENT METHOD',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        _MethodCard(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Wallet Credits',
          subtitle: _wallet == null
              ? 'Set up your wallet first'
              : _walletSufficient
                  ? 'Balance: ${WalletFormatters.currency(_wallet!.balance)}'
                  : 'Insufficient — Balance: ${WalletFormatters.currency(_wallet!.balance)}',
          isSelected: _selected == OrderPaymentMethod.wallet,
          isDisabled: !_walletSufficient,
          onTap: () => _select(OrderPaymentMethod.wallet),
        ),
        const SizedBox(height: 10),
        _MethodCard(
          icon: Icons.payment_rounded,
          title: 'Direct Payment',
          subtitle: 'UPI · Card · Net Banking',
          isSelected: _selected == OrderPaymentMethod.directPayment,
          isDisabled: false,
          onTap: () => _select(OrderPaymentMethod.directPayment),
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.06)
            : AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 1.8 : 1,
        ),
      ),
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Radio indicator
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : isDisabled
                            ? AppColors.border
                            : AppColors.textMuted,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              // Icon
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDisabled
                      ? AppColors.border
                      : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isDisabled ? AppColors.textMuted : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDisabled
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDisabled
                            ? AppColors.error.withValues(alpha: 0.7)
                            : AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDisabled)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectorShimmer extends StatelessWidget {
  const _SelectorShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 130,
          height: 13,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(7),
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          2,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              width: double.infinity,
              height: 66,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
