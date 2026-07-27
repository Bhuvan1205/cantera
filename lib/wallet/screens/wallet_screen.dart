import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../models/wallet_model.dart';
import '../models/wallet_transaction_model.dart';
import '../services/wallet_service.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/wallet_balance_card.dart';
import 'add_money_screen.dart';
import 'transaction_history_screen.dart';

/// The main Wallet screen accessible from the user's Profile page.
///
/// Shows:
///  - [WalletBalanceCard] with live balance
///  - Pending deposit status (if any awaiting admin review)
///  - 3 most recent transactions
///  - "View All Transactions" link
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            // No-op: streams auto-refresh. Included for pull-to-refresh UX.
          },
          child: StreamBuilder<WalletModel?>(
            stream: WalletService.watchWallet(userId),
            builder: (context, walletSnap) {
              final isLoading =
                  walletSnap.connectionState == ConnectionState.waiting;
              final wallet = walletSnap.data;

              return StreamBuilder<List<WalletTransactionModel>>(
                stream: WalletService.watchTransactions(userId, limit: 3),
                builder: (context, txSnap) {
                  if (txSnap.hasError) {
                    debugPrint('Transactions stream error: ${txSnap.error}');
                  }
                  final recentTx = txSnap.data ?? [];

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    children: [
                      // ── Balance card ─────────────────────────────────────
                      WalletBalanceCard(
                        wallet: wallet,
                        isLoading: isLoading,
                        onAddMoney: () => _openAddMoney(context, userId),
                      ),
                      const SizedBox(height: 24),

                      // ── Pending deposit notice ────────────────────────────
                      _PendingDepositBanner(userId: userId),

                      // ── Recent transactions ───────────────────────────────
                      _buildRecentTransactionsSection(
                        context: context,
                        userId: userId,
                        transactions: recentTx,
                        isLoading:
                            txSnap.connectionState == ConnectionState.waiting,
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      title: const Text('My Wallet'),
    );
  }

  Widget _buildRecentTransactionsSection({
    required BuildContext context,
    required String userId,
    required List<WalletTransactionModel> transactions,
    required bool isLoading,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            if (transactions.isNotEmpty)
              GestureDetector(
                onTap: () => _openHistory(context, userId),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),

        if (isLoading)
          const _TransactionListShimmer()
        else if (transactions.isEmpty)
          _EmptyTransactions(onAddMoney: () => _openAddMoney(context, FirebaseAuth.instance.currentUser!.uid))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (_, i) => TransactionTile(transaction: transactions[i]),
          ),
      ],
    );
  }

  void _openAddMoney(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMoneyScreen(userId: userId),
      ),
    );
  }

  void _openHistory(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionHistoryScreen(userId: userId),
      ),
    );
  }
}

// ── Pending deposit banner ─────────────────────────────────────────────────────

class _PendingDepositBanner extends StatelessWidget {
  const _PendingDepositBanner({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: WalletService.watchUserPendingDeposits(userId),
      builder: (context, snap) {
        final deposits = snap.data ?? [];
        final pending = deposits.where((d) => d.isPending).toList();
        if (pending.isEmpty) return const SizedBox(height: 0);

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD966), width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.hourglass_top_rounded,
                  color: Color(0xFF856404),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${pending.length} deposit${pending.length > 1 ? 's' : ''} pending review',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF856404),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Your payment was received. Credits will be added once the admin verifies it.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF856404),
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions({required this.onAddMoney});
  final VoidCallback onAddMoney;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 28,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add money to your wallet\nto get started.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: onAddMoney,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Money'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading shimmer ────────────────────────────────────────────────────────────

class _TransactionListShimmer extends StatelessWidget {
  const _TransactionListShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 74,
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
          ),
        ),
      ),
    );
  }
}
