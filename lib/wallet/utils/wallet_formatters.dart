import '../models/wallet_transaction_model.dart';

/// Utility functions for formatting wallet-related display values.
///
/// All functions are pure (no side effects) for easy unit testing.
abstract final class WalletFormatters {
  // ── Currency ─────────────────────────────────────────────────────────────

  /// Formats [amount] as `₹250` (no decimals for whole numbers)
  /// or `₹250.50` (with decimals for fractional amounts).
  static String currency(double amount) {
    if (amount == amount.truncate()) {
      return '₹${amount.toInt()}';
    }
    return '₹${amount.toStringAsFixed(2)}';
  }

  /// Formats [amount] with always-two-decimal places: `₹250.00`.
  static String currencyExact(double amount) =>
      '₹${amount.toStringAsFixed(2)}';

  // ── Dates ────────────────────────────────────────────────────────────────

  /// Formats a [DateTime] as `14 Jul 2026, 3:45 PM`.
  static String dateTime(DateTime dt) {
    final local = dt.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = local.hour > 12
        ? local.hour - 12
        : (local.hour == 0 ? 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day} ${months[local.month - 1]} ${local.year}, $hour:$minute $period';
  }

  /// Formats a [DateTime] as a short relative label:
  /// `Today`, `Yesterday`, or `14 Jul 2026`.
  static String relativeDate(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  // ── Transaction display ───────────────────────────────────────────────────

  /// Returns `+₹250` for credit transactions, `-₹250` for debits.
  static String signedAmount(WalletTransactionModel tx) {
    final prefix = tx.isCredit ? '+' : '-';
    return '$prefix${currency(tx.amount)}';
  }
}
