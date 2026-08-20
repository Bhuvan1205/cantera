import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/services/api_client.dart';
import '../../theme/app_colors.dart';

/// Live Queue board for the Canteen Staff Terminal.
///
/// Streams the `queues` collection in real-time and displays a kanban-style
/// board grouped by item name.  Each column shows:
///   - NOW PREPARING  — the token currently being made (status == 'preparing')
///   - UP NEXT / WAITING — remaining tokens in order
class StaffQueueTab extends StatelessWidget {
  const StaffQueueTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('queues').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading queue: ${snapshot.error}',
              style: const TextStyle(color: AppColors.error),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        // Filter only queues with at least one active entry
        final activeQueues = docs.where((doc) {
          final queue = doc.data()['queue'] as List<dynamic>? ?? [];
          return queue.isNotEmpty;
        }).toList();

        return ListView(
          padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.of(context).padding.bottom + 88),
          children: [
            // Header
            const Text(
              'LIVE KITCHEN QUEUE',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Preparation\nBoard',
              style: TextStyle(
                height: 1.05,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Real-time view of all active items being prepared at each counter.',
              style: TextStyle(
                height: 1.5,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),

            if (activeQueues.isEmpty)
              _buildEmptyState()
            else
              ...activeQueues.map((doc) {
                final rawName = doc.data()['item_name'] as String? ?? doc.id;
                final formattedName = rawName.isEmpty ? rawName : rawName[0].toUpperCase() + rawName.substring(1).toLowerCase();
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _QueueItemCard(
                    itemName: formattedName,
                    avgPrepMins:
                        (doc.data()['avg_prep_time_mins'] as num?)?.toInt() ?? 5,
                    queue: List<Map<String, dynamic>>.from(
                      (doc.data()['queue'] as List<dynamic>? ?? [])
                          .map((e) => Map<String, dynamic>.from(e as Map)),
                    ),
                  ),
                );
              }),
          ],
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
          Icon(
            Icons.check_circle_outline_rounded,
            size: 56,
            color: AppColors.success.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Queue is Clear',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'No items are currently being prepared.',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Per-item queue card ───────────────────────────────────────────────────────

class _QueueItemCard extends StatelessWidget {
  const _QueueItemCard({
    required this.itemName,
    required this.avgPrepMins,
    required this.queue,
  });

  final String itemName;
  final int avgPrepMins;
  final List<Map<String, dynamic>> queue;

  @override
  Widget build(BuildContext context) {
    final preparing = queue
        .where((e) => (e['status'] as String? ?? '') == 'preparing')
        .toList();
    final waiting = queue
        .where((e) => (e['status'] as String? ?? '') == 'waiting')
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_dining_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    itemName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '~$avgPrepMins min/order',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
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
                // NOW PREPARING section
                if (preparing.isNotEmpty) ...[
                  _SectionLabel(
                    label: 'NOW PREPARING',
                    color: AppColors.readyBrown,
                    icon: Icons.local_fire_department_rounded,
                  ),
                  const SizedBox(height: 8),
                  ...preparing.map((e) => _TokenRow(
                        entry: e,
                        isPreparing: true,
                      )),
                  const SizedBox(height: 14),
                ],

                // UP NEXT section
                if (waiting.isNotEmpty) ...[
                  _SectionLabel(
                    label: 'UP NEXT',
                    color: AppColors.textMuted,
                    icon: Icons.hourglass_empty_rounded,
                  ),
                  const SizedBox(height: 8),
                  ...waiting.take(5).map((e) => _TokenRow(
                        entry: e,
                        isPreparing: false,
                      )),
                  if (waiting.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '+${waiting.length - 5} more in queue',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                ],

                if (preparing.isEmpty && waiting.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'All items delivered.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TokenRow extends StatefulWidget {
  const _TokenRow({required this.entry, required this.isPreparing});

  final Map<String, dynamic> entry;
  final bool isPreparing;

  @override
  State<_TokenRow> createState() => _TokenRowState();
}

class _TokenRowState extends State<_TokenRow> {
  bool _isLoading = false;

  Future<void> _markPrepared() async {
    setState(() => _isLoading = true);
    try {
      final orderId = widget.entry['order_id'] as String?;
      final category = widget.entry['token_id'] as String?; // token_id stores category

      if (orderId == null || category == null) {
        throw Exception('Missing orderId or category');
      }

      await ApiClient.instance.post(
        '/api/orders/$orderId/mark-prepared',
        body: {'category': category},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${category.toUpperCase()} order marked prepared!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokenNumber = widget.entry['token_number'] as int?;
    final tokenId = widget.entry['token_id'] as String? ?? '';
    final displayLabel = tokenNumber != null
        ? 'Token #$tokenNumber'
        : 'Token ${tokenId.length > 6 ? tokenId.substring(0, 6) : tokenId}';

    final itemsList = widget.entry['items'] as List<dynamic>? ?? [];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isPreparing
            ? AppColors.readyBrown.withValues(alpha: 0.07)
            : AppColors.summaryCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isPreparing
              ? AppColors.readyBrown.withValues(alpha: 0.25)
              : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.isPreparing
                  ? AppColors.readyBrown
                  : AppColors.textMuted.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: widget.isPreparing ? AppColors.readyBrown : AppColors.primary,
                  ),
                ),
                if (itemsList.isNotEmpty) const SizedBox(height: 6),
                if (itemsList.isNotEmpty)
                  ...itemsList.map((itemData) {
                    final map = itemData as Map<String, dynamic>;
                    final name = map['item_name'] as String? ?? map['name'] as String? ?? 'Unknown';
                    final qty = (map['quantity'] as num?)?.toInt() ?? 1;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '• $qty x $name',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
          if (widget.isPreparing)
            ElevatedButton(
              onPressed: _isLoading ? null : _markPrepared,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.readyBrown,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Mark Ready',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
