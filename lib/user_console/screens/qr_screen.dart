import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../theme/app_colors.dart';
import '../utils/app_keys.dart';

// ── Category metadata ─────────────────────────────────────────────────────────

class _CategoryMeta {
  final String label;
  final IconData icon;
  final Color color;

  const _CategoryMeta({
    required this.label,
    required this.icon,
    required this.color,
  });
}

const _categoryMeta = <String, _CategoryMeta>{
  'bakery': _CategoryMeta(
    label: 'Bakery',
    icon: Icons.bakery_dining_rounded,
    color: Color(0xFFD68A37),
  ),
  'mess': _CategoryMeta(
    label: 'Mess',
    icon: Icons.restaurant_rounded,
    color: AppColors.primary,
  ),
  'beverages': _CategoryMeta(
    label: 'Beverages',
    icon: Icons.local_cafe_rounded,
    color: Color(0xFF6A3FA0),
  ),
};

_CategoryMeta _metaFor(String cat) =>
    _categoryMeta[cat.toLowerCase()] ??
    _CategoryMeta(
      label: cat[0].toUpperCase() + cat.substring(1),
      icon: Icons.category_rounded,
      color: AppColors.primary,
    );

// ── Main screen ───────────────────────────────────────────────────────────────

class OrderQrScreen extends StatefulWidget {
  const OrderQrScreen({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  State<OrderQrScreen> createState() => _OrderQrScreenState();
}

class _OrderQrScreenState extends State<OrderQrScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _orderStream;

  @override
  void initState() {
    super.initState();
    _orderStream = FirebaseFirestore.instance
        .collection('Orders')
        .doc(widget.orderId)
        .snapshots();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _normalizeOrderStatus(String? status) {
    switch ((status ?? 'pending').toLowerCase()) {
      case 'pending':
        return 'pending';
      case 'placed':
        return 'placed';
      case 'preparing':
        return 'preparing';
      case 'delivered':
        return 'delivered';
      case 'refund_pending':
        return 'refund_pending';
      case 'refunded':
      case 'cancelled':
        return 'cancelled';
      default:
        return 'pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _orderStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.bg,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            backgroundColor: AppColors.bg,
            body: Center(child: Text('Order not found')),
          );
        }

        final data = snapshot.data!.data()!;
        final overallStatus =
            _normalizeOrderStatus(data['status'] as String?);

        if (overallStatus == 'cancelled') {
          return Scaffold(
            backgroundColor: AppColors.bg,
            appBar: AppBar(
              leading: IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
              title: const Text('Cancelled Order'),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.cancel_outlined,
                      color: AppColors.error,
                      size: 80,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Order Refunded',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This order has been cancelled and refunded to your wallet. The pickup QR code is no longer valid.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => Navigator.maybePop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(200, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Back to Order'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final categoryTokens =
            data['categoryTokens'] as Map<String, dynamic>?;

        // ── Build category token list ─────────────────────────────────────────
        // Sort alphabetically for consistent ordering (matches placeOrder)
        final List<_CategoryTokenInfo> tokens = [];

        if (categoryTokens != null && categoryTokens.isNotEmpty) {
          final sortedKeys = categoryTokens.keys.toList()..sort();
          for (final cat in sortedKeys) {
            if (cat.toLowerCase() == 'mess') continue; // DO NOT include Mess tokens for QR pickup
            final catData = categoryTokens[cat] as Map<String, dynamic>;
            final tokenId = catData['tokenId'] as String? ?? '';
            final tokenNumber =
                ((catData['tokenNumber'] ?? 0) as num).toInt();
            final catStatus = _normalizeOrderStatus(
              catData['status'] as String?,
            );
            final rawItems =
                (catData['items'] as List<dynamic>? ?? []);
            final items = rawItems
                .map((e) => e as Map<String, dynamic>)
                .toList();
            tokens.add(_CategoryTokenInfo(
              category: cat,
              tokenId: tokenId,
              tokenNumber: tokenNumber,
              status: catStatus,
              items: items,
            ));
          }
        }

        // Fallback: no categoryTokens → single legacy QR
        if (tokens.isEmpty) {
          if (categoryTokens != null && categoryTokens.isNotEmpty) {
            return Scaffold(
              backgroundColor: AppColors.bg,
              appBar: AppBar(
                leading: IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
              ),
              body: const Center(
                child: Text(
                  'No QR available for this order.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            );
          }
          final isDelivered = overallStatus == 'delivered';
          final isCancelled = overallStatus == 'cancelled';
          return _buildScaffold(
            context: context,
            pageCount: 1,
            child: _SingleQrView(
              orderId: widget.orderId,
              isDelivered: isDelivered,
              isCancelled: isCancelled,
              tokenNumber:
                  ((data['tokenNumber'] ?? 0) as num).toInt(),
            ),
          );
        }

        // ── Multi-token PageView ───────────────────────────────────────────────
        return _buildScaffold(
          context: context,
          pageCount: tokens.length,
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: tokens.length,
                  onPageChanged: (i) =>
                      setState(() => _currentPage = i),
                  itemBuilder: (context, index) {
                    final token = tokens[index];
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
                      child: _CategoryQrCard(
                        token: token,
                        totalTokens: tokens.length,
                        currentIndex: index,
                      ),
                    );
                  },
                ),
              ),
              if (tokens.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: _DotsIndicator(
                    count: tokens.length,
                    current: _currentPage,
                    tokens: tokens,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Scaffold _buildScaffold({
    required BuildContext context,
    required int pageCount,
    required Widget child,
  }) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: Text(
          pageCount > 1 ? 'Pickup QR Codes' : 'Pickup QR Code',
        ),
      ),
      body: SafeArea(child: child),
    );
  }
}

// ── Category token info model ─────────────────────────────────────────────────

class _CategoryTokenInfo {
  final String category;
  final String tokenId;
  final int tokenNumber;
  final String status;
  final List<Map<String, dynamic>> items;

  const _CategoryTokenInfo({
    required this.category,
    required this.tokenId,
    required this.tokenNumber,
    required this.status,
    required this.items,
  });

  bool get isDelivered => status.toLowerCase() == 'delivered';
  bool get isCancelled =>
      status.toLowerCase() == 'cancelled' ||
      status.toLowerCase() == 'refunded';
}

// ── Per-category QR card ──────────────────────────────────────────────────────

class _CategoryQrCard extends StatelessWidget {
  const _CategoryQrCard({
    required this.token,
    required this.totalTokens,
    required this.currentIndex,
  });

  final _CategoryTokenInfo token;
  final int totalTokens;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final meta = _metaFor(token.category);
    final isDelivered = token.isDelivered;
    final isCancelled = token.isCancelled;
    final isInactive = isDelivered || isCancelled;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Page indicator label ──────────────────────────────────────────────
        if (totalTokens > 1) ...[
          Text(
            'TOKEN ${currentIndex + 1} OF $totalTokens',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
        ],

        // ── Status label ──────────────────────────────────────────────────────
        Text(
          isCancelled
              ? 'Refunded Order'
              : isDelivered
                  ? 'Token Used'
                  : 'Show at Counter',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: isInactive ? AppColors.error : AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),

        // ── Category + section name ───────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(meta.icon, size: 20, color: meta.color),
            const SizedBox(width: 8),
            Text(
              meta.label,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: isInactive ? AppColors.textMuted : AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          isCancelled
              ? 'Order refunded / cancelled'
              : 'Present at ${meta.label} counter',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),

        // ── QR card ───────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: meta.color.withValues(alpha: 0.07),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // QR or deactivated state
              if (isInactive)
                Container(
                  key: AppKeys.qrDeactivatedView,
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.errorBorder,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.block_rounded,
                        size: 64,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isCancelled ? 'QR Invalid' : 'Token Used',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: QrImageView(
                    key: AppKeys.qrCodeView,
                    data: token.tokenId,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: meta.color,
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: meta.color,
                    ),
                  ),
                ),

              const SizedBox(height: 20),
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 16),

              // Token number
              Row(
                children: [
                  _InfoChip(
                    label: 'TOKEN NO.',
                    value: '#${token.tokenNumber}',
                    color: meta.color,
                  ),
                  const Spacer(),
                  _InfoChip(
                    label: 'SECTION',
                    value: meta.label.toUpperCase(),
                    color: meta.color,
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 16),

              // Items in this category
              _ItemsList(items: token.items, color: meta.color),
            ],
          ),
        ),

        // ── Swipe hint (multi-token only) ─────────────────────────────────────
        if (totalTokens > 1 && !isDelivered) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.swipe_rounded,
                  size: 16,
                  color: meta.color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Swipe to see other section tokens',
                    style: TextStyle(
                      fontSize: 13,
                      color: meta.color,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else if (!isDelivered) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Present this QR code to the canteen staff when collecting your order.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Info chip (token number / section label) ──────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ── Items list inside QR card ─────────────────────────────────────────────────

class _ItemsList extends StatelessWidget {
  const _ItemsList({required this.items, required this.color});

  final List<Map<String, dynamic>> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ITEMS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) {
          final name = item['name'] as String? ?? '';
          final qty = ((item['quantity'] ?? 1) as num).toInt();
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  'x$qty',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── Page dots indicator ───────────────────────────────────────────────────────

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({
    required this.count,
    required this.current,
    required this.tokens,
  });

  final int count;
  final int current;
  final List<_CategoryTokenInfo> tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isSelected = i == current;
        final meta = _metaFor(tokens[i].category);
        final delivered = tokens[i].isDelivered;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: isSelected ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: delivered
                ? AppColors.error.withValues(alpha: isSelected ? 1.0 : 0.4)
                : meta.color.withValues(alpha: isSelected ? 1.0 : 0.3),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

// ── Legacy single-QR fallback (orders without categoryTokens) ─────────────────

class _SingleQrView extends StatelessWidget {
  const _SingleQrView({
    required this.orderId,
    required this.isDelivered,
    required this.isCancelled,
    required this.tokenNumber,
  });

  final String orderId;
  final bool isDelivered;
  final bool isCancelled;
  final int tokenNumber;

  @override
  Widget build(BuildContext context) {
    final isInactive = isDelivered || isCancelled;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isCancelled
                ? 'Refunded Order'
                : isDelivered
                    ? 'Order Delivered'
                    : 'Ready for Pickup',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: isInactive ? AppColors.error : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isCancelled
                ? 'Order Refunded'
                : isDelivered
                    ? 'QR Deactivated'
                    : 'Show at counter',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isInactive)
                  Container(
                    key: AppKeys.qrDeactivatedView,
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: AppColors.errorBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.errorBorder,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.block_rounded,
                          size: 72,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isCancelled ? 'QR Invalid' : 'QR Deactivated',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: QrImageView(
                      key: AppKeys.qrCodeView,
                      data: orderId,
                      version: QrVersions.auto,
                      size: 220,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: AppColors.primary,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Container(height: 1, color: AppColors.border),
                const SizedBox(height: 18),
                const Text(
                  'Token Number',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '#$tokenNumber',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          if (!isDelivered)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Present this QR code to the canteen staff when collecting your order.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
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
