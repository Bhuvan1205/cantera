import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../models/wallet_transaction_model.dart';
import '../services/wallet_service.dart';
import '../utils/wallet_formatters.dart';
import '../widgets/transaction_tile.dart';

/// Full paginated transaction history screen.
///
/// Shows all wallet transactions for the user in reverse chronological order.
/// Supports filtering by transaction type.
class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key, required this.userId});

  final String userId;

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  WalletTransactionType? _activeFilter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('Transaction History'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Filter chips ─────────────────────────────────────────────────
            _FilterBar(
              activeFilter: _activeFilter,
              onFilterChanged: (filter) =>
                  setState(() => _activeFilter = filter),
            ),

            // ── Transaction list ─────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<WalletTransactionModel>>(
                stream: WalletService.watchTransactions(
                  widget.userId,
                  limit: 100,
                ),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  if (snap.hasError) {
                    return Center(
                      child: Text(
                        'Error loading transactions.\n${snap.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    );
                  }

                  var transactions = snap.data ?? [];

                  // Apply type filter client-side (avoids extra index).
                  if (_activeFilter != null) {
                    transactions = transactions
                        .where((tx) => tx.type == _activeFilter)
                        .toList();
                  }

                  if (transactions.isEmpty) {
                    return const _EmptyHistory();
                  }

                  // Group by date for section headers.
                  final grouped = _groupByDate(transactions);
                  final dateKeys = grouped.keys.toList();

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    itemCount: dateKeys.length,
                    itemBuilder: (context, sectionIdx) {
                      final dateLabel = dateKeys[sectionIdx];
                      final sectionTxs = grouped[dateLabel]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              dateLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          ...sectionTxs.map(
                            (tx) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: TransactionTile(transaction: tx),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Groups transactions by their relative date label (Today, Yesterday, etc.).
  Map<String, List<WalletTransactionModel>> _groupByDate(
    List<WalletTransactionModel> transactions,
  ) {
    final map = <String, List<WalletTransactionModel>>{};
    for (final tx in transactions) {
      final label = WalletFormatters.relativeDate(tx.timestamp);
      map.putIfAbsent(label, () => []).add(tx);
    }
    return map;
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.activeFilter,
    required this.onFilterChanged,
  });

  final WalletTransactionType? activeFilter;
  final void Function(WalletTransactionType?) onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final filters = <String, WalletTransactionType?>{
      'All': null,
      'Added': WalletTransactionType.deposit,
      'Spent': WalletTransactionType.purchase,
      'Refunds': WalletTransactionType.refund,
    };

    return Container(
      height: 52,
      color: AppColors.bg,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: filters.entries.map((entry) {
          final isActive = activeFilter == entry.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onFilterChanged(entry.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      isActive ? AppColors.primary : AppColors.cardBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isActive
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color:
                        isActive ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 30,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No transactions found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try changing the filter above.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
