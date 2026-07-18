import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../models/wallet_transaction_model.dart';
import '../utils/wallet_formatters.dart';

/// A single row in the transaction history list.
///
/// Shows the transaction icon, title, date, signed amount and status.
/// Used in both [WalletScreen] (recent 3) and [TransactionHistoryScreen] (all).
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
  });

  final WalletTransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.isCredit;
    final isPending =
        transaction.status == WalletTransactionStatus.pending;
    final isFailed = transaction.status == WalletTransactionStatus.failed ||
        transaction.status == WalletTransactionStatus.cancelled;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Icon ──────────────────────────────────────────────────────────
          _TxIcon(type: transaction.type, isCredit: isCredit),
          const SizedBox(width: 14),

          // ── Title + date ──────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description.isNotEmpty
                      ? transaction.description
                      : transaction.type.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  WalletFormatters.relativeDate(transaction.timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ── Amount + status ───────────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                WalletFormatters.signedAmount(transaction),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isFailed
                      ? AppColors.textMuted
                      : isCredit
                          ? AppColors.success
                          : AppColors.textPrimary,
                  decoration:
                      isFailed ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 4),
              _StatusPill(
                status: transaction.status,
                isPending: isPending,
                isFailed: isFailed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TxIcon extends StatelessWidget {
  const _TxIcon({required this.type, required this.isCredit});

  final WalletTransactionType type;
  final bool isCredit;

  IconData get _icon {
    switch (type) {
      case WalletTransactionType.deposit:
        return Icons.arrow_downward_rounded;
      case WalletTransactionType.purchase:
        return Icons.shopping_bag_rounded;
      case WalletTransactionType.refund:
        return Icons.refresh_rounded;
      case WalletTransactionType.adjustment:
        return Icons.tune_rounded;
      case WalletTransactionType.bonus:
        return Icons.card_giftcard_rounded;
      case WalletTransactionType.cashback:
        return Icons.monetization_on_rounded;
      case WalletTransactionType.reversal:
        return Icons.history_rounded;
    }
  }

  Color get _bgColor {
    switch (type) {
      case WalletTransactionType.deposit:
        return AppColors.success.withValues(alpha: 0.1);
      case WalletTransactionType.purchase:
        return AppColors.primary.withValues(alpha: 0.08);
      case WalletTransactionType.refund:
        return AppColors.terracotta.withValues(alpha: 0.12);
      case WalletTransactionType.adjustment:
        return AppColors.accent.withValues(alpha: 0.1);
      case WalletTransactionType.bonus:
        return AppColors.success.withValues(alpha: 0.1);
      case WalletTransactionType.cashback:
        return AppColors.success.withValues(alpha: 0.1);
      case WalletTransactionType.reversal:
        return AppColors.terracotta.withValues(alpha: 0.12);
    }
  }

  Color get _iconColor {
    switch (type) {
      case WalletTransactionType.deposit:
        return AppColors.success;
      case WalletTransactionType.purchase:
        return AppColors.primary;
      case WalletTransactionType.refund:
        return AppColors.accent;
      case WalletTransactionType.adjustment:
        return AppColors.accent;
      case WalletTransactionType.bonus:
        return AppColors.success;
      case WalletTransactionType.cashback:
        return AppColors.success;
      case WalletTransactionType.reversal:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(_icon, color: _iconColor, size: 20),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.status,
    required this.isPending,
    required this.isFailed,
  });

  final WalletTransactionStatus status;
  final bool isPending;
  final bool isFailed;

  @override
  Widget build(BuildContext context) {
    if (status == WalletTransactionStatus.success) {
      return const SizedBox.shrink();
    }

    final Color bg;
    final Color textColor;
    final String label;

    if (isPending) {
      bg = const Color(0xFFFFF3CD);
      textColor = const Color(0xFF856404);
      label = 'PENDING';
    } else if (isFailed) {
      bg = AppColors.errorBg;
      textColor = AppColors.error;
      label = status == WalletTransactionStatus.cancelled
          ? 'CANCELLED'
          : 'FAILED';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
