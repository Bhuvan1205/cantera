import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';

/// Live Queue screen for the customer / student console.
///
/// Streams the `queues` Firestore collection and renders each active food item
/// queue.  The current user's tokens are highlighted with estimated wait times.
class QueueScreen extends StatelessWidget {
  const QueueScreen({
    super.key,
    this.onHomeTap,
    this.onOrdersTap,
    this.onCartTap,
  });

  final VoidCallback? onHomeTap;
  final VoidCallback? onOrdersTap;
  final VoidCallback? onCartTap;

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'CANTEEN',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: AppBottomNav(
        selectedTab: NavTab.queue,
        onHomeTap: onHomeTap,
        onOrdersTap: onOrdersTap,
        onCartTap: onCartTap,
      ),
      body: SafeArea(
        bottom: false,
        child: _QueueBody(userId: userId),
      ),
    );
  }
}

class _QueueBody extends StatefulWidget {
  const _QueueBody({required this.userId});

  final String? userId;

  @override
  State<_QueueBody> createState() => _QueueBodyState();
}

class _QueueBodyState extends State<_QueueBody> {
  late Future<QuerySnapshot<Map<String, dynamic>>> _queuesFuture;

  @override
  void initState() {
    super.initState();
    _fetchQueues();
  }

  void _fetchQueues() {
    _queuesFuture = FirebaseFirestore.instance
        .collection('queues')
        .get(const GetOptions(source: Source.serverAndCache));
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _fetchQueues();
    });
    await _queuesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: _queuesFuture,
      builder: (context, queueSnap) {
        if (queueSnap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (queueSnap.hasError) {
          return Center(
            child: Text(
              'Error: ${queueSnap.error}',
              style: const TextStyle(color: AppColors.error),
            ),
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: widget.userId == null
              ? null
              : FirebaseFirestore.instance
                  .collection('Orders')
                  .where('userId', isEqualTo: widget.userId)
                  .where('overall_status', isEqualTo: 'active')
                  .snapshots(),
          builder: (context, ordersSnap) {
            // Build a set of all token_ids belonging to the current user
            final userTokenIds = <String>{};
            if (ordersSnap.hasData) {
              for (final doc in ordersSnap.data!.docs) {
                final catTokens =
                    doc.data()['categoryTokens'] as Map<String, dynamic>?;
                if (catTokens == null) continue;
                for (final cat in catTokens.values) {
                  final tokenId = (cat as Map<String, dynamic>)['tokenId']
                      as String?;
                  if (tokenId != null) {
                    // tokenId is "orderId::tokenDocId" — we only need tokenDocId
                    final parts = tokenId.split('::');
                    if (parts.length == 2) userTokenIds.add(parts[1]);
                  }
                }
              }
            }

            final docs = queueSnap.data?.docs ?? [];
            final activeQueues = docs.where((doc) {
              final queue = doc.data()['queue'] as List<dynamic>? ?? [];
              // Show queue if it has active (non-delivered) entries
              return queue.any((e) {
                final s = (e as Map)['status'] as String? ?? '';
                return s != 'delivered';
              });
            }).toList();

            return RefreshIndicator(
              onRefresh: _handleRefresh,
              color: AppColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
                children: [
                  // Header
                  const Text(
                    'Live Queue',
                    style: TextStyle(
                      fontSize: 32,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Track real-time preparation status for all mess items.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (activeQueues.isEmpty)
                    _buildEmptyState()
                  else
                    ...activeQueues.map((doc) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _UserQueueCard(
                          itemName:
                              doc.data()['item_name'] as String? ?? doc.id,
                          avgPrepMins:
                              (doc.data()['avg_prep_time_mins'] as num?)
                                      ?.toInt() ??
                                  5,
                          queue: List<Map<String, dynamic>>.from(
                            (doc.data()['queue'] as List<dynamic>? ?? [])
                                .map((e) => Map<String, dynamic>.from(e as Map)),
                          ),
                          userTokenIds: userTokenIds,
                        ),
                      );
                    }),
                ],
              ),
            );
          },
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
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 40,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'No Active Queues',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'The kitchen is currently free — your order\nwill be processed promptly.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Per-item queue card ───────────────────────────────────────────────────────

class _UserQueueCard extends StatelessWidget {
  const _UserQueueCard({
    required this.itemName,
    required this.avgPrepMins,
    required this.queue,
    required this.userTokenIds,
  });

  final String itemName;
  final int avgPrepMins;
  final List<Map<String, dynamic>> queue;
  final Set<String> userTokenIds;

  @override
  Widget build(BuildContext context) {
    // Compute user's position & wait time
    int? userPosition;
    double prepUnitsAhead = 0;

    for (int i = 0; i < queue.length; i++) {
      final entry = queue[i];
      final tokenId = entry['token_id'] as String? ?? '';
      final status = (entry['status'] as String? ?? '').toLowerCase();
      if (status == 'delivered') continue;

      if (userTokenIds.contains(tokenId)) {
        userPosition = i + 1;
        break;
      }
      prepUnitsAhead += (entry['prep_units'] as num?)?.toDouble() ?? 0;
    }

    final estimatedWaitMins =
        userPosition != null ? (prepUnitsAhead * avgPrepMins).round() : null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: userPosition != null
              ? const Color(0xFFB87333).withValues(alpha: 0.4)
              : AppColors.border,
          width: userPosition != null ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: userPosition != null
                ? const Color(0xFFB87333).withValues(alpha: 0.06)
                : AppColors.primary.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: userPosition != null
                  ? const Color(0xFFB87333).withValues(alpha: 0.06)
                  : AppColors.primary.withValues(alpha: 0.04),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.restaurant_rounded,
                  size: 18,
                  color: userPosition != null
                      ? const Color(0xFFB87333)
                      : AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    itemName,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: userPosition != null
                          ? const Color(0xFFB87333)
                          : AppColors.primary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (userPosition != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB87333).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'YOUR ORDER',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Color(0xFFB87333),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // My position banner
                if (userPosition != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB87333).withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFB87333).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'YOUR POSITION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: Color(0xFFB87333),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              userPosition == 1
                                  ? 'Now preparing!'
                                  : '#$userPosition in queue',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB87333),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Spacer(),
                            if (estimatedWaitMins != null) ...[
                              const Icon(
                                Icons.schedule_rounded,
                                size: 15,
                                color: Color(0xFFB87333),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                estimatedWaitMins == 0
                                    ? 'Ready soon'
                                    : '~$estimatedWaitMins min wait',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB87333),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // All queue entries
                ...queue.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final e = entry.value;
                  final status =
                      (e['status'] as String? ?? '').toLowerCase();
                  if (status == 'delivered') return const SizedBox.shrink();

                  final tokenId = e['token_id'] as String? ?? '';
                  final isMyToken = userTokenIds.contains(tokenId);
                  final tokenNumber = e['token_number'] as int?;
                  final displayLabel = tokenNumber != null
                      ? 'Token #$tokenNumber'
                      : 'Token ${(idx + 1)}';
                  final isPreparing = status == 'preparing';

                  return _UserTokenRow(
                    label: isMyToken ? '$displayLabel  (You)' : displayLabel,
                    isPreparing: isPreparing,
                    isMyToken: isMyToken,
                    position: idx + 1,
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTokenRow extends StatelessWidget {
  const _UserTokenRow({
    required this.label,
    required this.isPreparing,
    required this.isMyToken,
    required this.position,
  });

  final String label;
  final bool isPreparing;
  final bool isMyToken;
  final int position;

  @override
  Widget build(BuildContext context) {
    final Color rowColor;
    final Color textColor;
    final Color dotColor;

    if (isMyToken) {
      rowColor = const Color(0xFFB87333).withValues(alpha: 0.09);
      textColor = const Color(0xFFB87333);
      dotColor = const Color(0xFFB87333);
    } else if (isPreparing) {
      rowColor = AppColors.success.withValues(alpha: 0.06);
      textColor = AppColors.success;
      dotColor = AppColors.success;
    } else {
      rowColor = AppColors.summaryCard;
      textColor = AppColors.primary;
      dotColor = AppColors.textMuted.withValues(alpha: 0.4);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: rowColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMyToken
              ? const Color(0xFFB87333).withValues(alpha: 0.25)
              : AppColors.border,
          width: isMyToken ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Position number
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: dotColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$position',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: dotColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isMyToken ? FontWeight.w800 : FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          if (isPreparing && !isMyToken)
            const Icon(
              Icons.local_fire_department_rounded,
              size: 16,
              color: AppColors.success,
            ),
          if (isMyToken)
            const Icon(
              Icons.person_rounded,
              size: 16,
              color: Color(0xFFB87333),
            ),
        ],
      ),
    );
  }
}
