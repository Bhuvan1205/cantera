import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../services/recommendation_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/recommendation_card.dart';

// ─── DATA MODEL ──────────────────────────────────────────────────────────────

class MenuItem {
  final String id;
  final String name;
  final String category;
  final int price;
  final String stockLabel;
  final bool canAddToCart;
  final String imageUrl;

  const MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stockLabel,
    required this.canAddToCart,
    required this.imageUrl,
  });
}

// ─── MENU SCREEN ─────────────────────────────────────────────────────────────

/// A presentational screen that renders a highly professional, categorised,
/// and searchable list of [MenuItem]s using Option A (Premium Organic) theme.
class MenuScreen extends StatefulWidget {
  const MenuScreen({
    super.key,
    required this.items,
    required this.categories,
    required this.onAddToCart,
    required this.onRemoveFromCart,
    required this.cart,
    this.userName,
    this.onCartTap,
    this.onOrdersTap,
    this.onQueueTap,
    this.onProfileTap,
    this.isLoading = false,
  });

  final List<MenuItem> items;
  final List<String> categories;
  final void Function(MenuItem item) onAddToCart;
  final void Function(MenuItem item) onRemoveFromCart;
  final Map<String, Map<String, dynamic>> cart;
  final String? userName;
  final VoidCallback? onCartTap;
  final VoidCallback? onOrdersTap;
  final VoidCallback? onQueueTap;
  final VoidCallback? onProfileTap;
  final bool isLoading;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String searchQuery = '';
  late String _selectedCategory;
  final ScrollController _scrollController = ScrollController();

  RecommendationState _recState = RecommendationState.loading;
  List<MenuItem> _recommendations = [];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.categories.any((c) => c.toLowerCase() == 'all items')
        ? 'all'
        : (widget.categories.isNotEmpty
            ? widget.categories.first.toLowerCase()
            : 'all');
    _fetchRecommendations();
  }

  @override
  void didUpdateWidget(covariant MenuScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items != oldWidget.items) {
      _fetchRecommendations();
    }
  }

  Future<void> _fetchRecommendations() async {
    if (widget.items.isEmpty) return;
    
    setState(() => _recState = RecommendationState.loading);
    final (state, recs) = await RecommendationService.getRecommendations(widget.items);
    
    if (mounted) {
      setState(() {
        _recState = state;
        _recommendations = recs;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Filtering Logic ────────────────────────────────────────────────────────

  List<MenuItem> get _filteredItems {
    // When the user is typing a search query, bypass the category filter
    // entirely and search the full menu — this is the "global search" behaviour
    // users expect (similar to Swiggy / Zomato).
    if (searchQuery.trim().isNotEmpty) {
      return widget.items.where((item) {
        return item.name.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }

    // No search query — apply category filter as normal.
    if (_selectedCategory == 'all') return widget.items;
    return widget.items
        .where((item) => item.category.toLowerCase() == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(),
      extendBody: true, // Allows content to flow behind floating bottom nav
      bottomNavigationBar: AppBottomNav(
        selectedTab: NavTab.home,
        onHomeTap: () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        },
        onOrdersTap: widget.onOrdersTap,
        onQueueTap: widget.onQueueTap,
        onCartTap: widget.onCartTap,
      ),
      body: SafeArea(
        bottom: false,
        child: widget.isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: ListView(
                          key: const PageStorageKey<String>('menu-list-view'),
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110), // Padding to clear bottom nav
                          children: [
                            _buildHeadline(),
                            const SizedBox(height: 24),
                            _buildRecommendationsSection(),
                            _buildCategoryAndSearchRow(),
                            const SizedBox(height: 24),
                            _buildItemList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Blinkit-style cart banner — appears when cart is non-empty
                  _CartBanner(
                    cart: widget.cart,
                    onViewCart: widget.onCartTap,
                  ),
                ],
              ),
      ),
    );
  }

  // ── Sub-builders ──────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
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
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: IconButton(
            onPressed: widget.onProfileTap,
            icon: const Icon(
              Icons.account_circle_outlined,
              color: AppColors.primary,
              size: 28,
            ),
            tooltip: 'Profile',
          ),
        ),
      ],
    );
  }

  Widget _buildHeadline() {
    final rawName = widget.userName?.trim() ?? 'Guest';
    final name = rawName.split(' ').first;
    final hour = DateTime.now().hour;
    final String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    return Text(
      '$greeting, $name',
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppColors.terracotta,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    if (_recState == RecommendationState.loading) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 24),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    
    if (_recState == RecommendationState.error || _recommendations.isEmpty) {
      return const SizedBox.shrink(); // Hide if error or no recommendations
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '⭐ Recommended For You',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 260,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _recommendations.length,
            clipBehavior: Clip.none,
            itemBuilder: (context, index) {
              final item = _recommendations[index];
              return RecommendationCard(
                name: item.name,
                price: item.price,
                imageUrl: item.imageUrl,
                category: item.category,
                onAddTap: () => widget.onAddToCart(item),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCategoryAndSearchRow() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // The category list view
    Widget categoryList = SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = widget.categories[index];
          final normalizedCategory =
              category.toLowerCase() == 'all items' ? 'all' : category.toLowerCase();
          final isSelected = normalizedCategory == _selectedCategory;

          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = normalizedCategory),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    // The search bar
    Widget searchBar = SizedBox(
      width: isMobile ? double.infinity : 360.0,
      height: 40,
      child: _SearchBar(
        onChanged: (value) {
          setState(() {
            searchQuery = value;
          });
        },
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchBar,
          const SizedBox(height: 16),
          categoryList,
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(child: categoryList),
          const SizedBox(width: 12),
          searchBar,
        ],
      );
    }
  }

  Widget _buildItemList() {
    final items = _filteredItems;

    if (items.isEmpty) {
      return const _EmptyState();
    }

    // Using Column instead of shrinkWrap ListView.builder — shrinkWrap forces
    // Flutter to measure all items upfront (no lazy rendering), which causes
    // jank with large lists. Column inside an outer ListView is equivalent
    // here since the inner list is already non-scrollable.
    return Column(
      children: [
        for (int index = 0; index < items.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _FoodCard(
              item: items[index],
              selectedCount: widget.cart[items[index].id]?['quantity'] as int? ?? 0,
              onAddTap: () => widget.onAddToCart(items[index]),
              onRemoveTap: () => widget.onRemoveFromCart(items[index]),
            ),
          ),
      ],
    );
  }
}

// ─── SEARCH BAR ───────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEFECE6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: TextField(
          onChanged: onChanged,
          style: const TextStyle(
            color: Color(0xFF0F382B),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search food...',
            hintStyle: TextStyle(
              color: const Color(0xFF5A6660).withValues(alpha: 0.5),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF0F382B),
              size: 18,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          ),
        ),
      ),
    );
  }
}



// ─── FOOD CARD ────────────────────────────────────────────────────────────────

class _FoodCard extends StatelessWidget {
  const _FoodCard({
    required this.item,
    required this.selectedCount,
    required this.onAddTap,
    required this.onRemoveTap,
  });

  final MenuItem item;
  final int selectedCount;
  final VoidCallback onAddTap;
  final VoidCallback onRemoveTap;

  @override
  Widget build(BuildContext context) {
    final isLowStock = item.stockLabel.contains('LOW');
    final isCritical = item.stockLabel.contains('OUT');
    final isUnavailable = !item.canAddToCart;

    // Premium Stock Indicator Color mapping
    final Color stockBadgeColor;
    if (isUnavailable || isCritical) {
      stockBadgeColor = AppColors.error;
    } else if (isLowStock) {
      stockBadgeColor = const Color(0xFFD68A37);
    } else {
      stockBadgeColor = AppColors.primary;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Curved Item Image ──────────────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: 110,
                    height: 110,
                    child: item.imageUrl.isEmpty
                        ? Container(
                            color: const Color(0xFFF3EDE4),
                            child: Icon(
                              Icons.restaurant_menu_rounded,
                              size: 36,
                              color: AppColors.primary.withValues(alpha: 0.5),
                            ),
                          )
                        : (item.imageUrl.startsWith('http://') || item.imageUrl.startsWith('https://'))
                            ? Image.network(
                                item.imageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: const Color(0xFFF3EDE4),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (_, _, _) => Container(
                                  color: const Color(0xFFF3EDE4),
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: 36,
                                    color: AppColors.primary.withValues(alpha: 0.5),
                                  ),
                                ),
                              )
                            : Image.asset(
                                item.imageUrl,
                                fit: BoxFit.cover,
                                // Decode at display size only — prevents large PNGs
                                // (some are 800KB+) from being decoded at full
                                // resolution. 220 = 110 logical px × 2× density.
                                cacheWidth: 220,
                                cacheHeight: 220,
                                errorBuilder: (_, _, _) => Container(
                                  color: const Color(0xFFF3EDE4),
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: 36,
                                    color: AppColors.primary.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                  ),
                ),
                if (selectedCount > 0)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.terracotta,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$selectedCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 16),

            // ── Info Grid ───────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _CategoryBadge(category: item.category),
                      // Professional clean stock text
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: stockBadgeColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.stockLabel,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: stockBadgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PRICE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: Color(0xFF8A9993),
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '₹${item.price}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      (selectedCount > 0 && !isUnavailable)
                          ? _QuantitySelector(
                              count: selectedCount,
                              onDecrease: onRemoveTap,
                              onIncrease: onAddTap,
                            )
                          : _AddButton(
                              onTap: isUnavailable ? null : onAddTap,
                            ),
                    ],
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

// ─── CATEGORY BADGE ───────────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5F2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── ADD BUTTON ───────────────────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  const _AddButton({
    this.onTap,
  });

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 48,
          height: 38,
          decoration: BoxDecoration(
            color: isDisabled ? Colors.grey.shade300 : AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Icon(
              isDisabled ? Icons.block_rounded : Icons.add_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── QUANTITY SELECTOR ────────────────────────────────────────────────────────

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({
    required this.count,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int count;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.summaryCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SelectorButton(
            icon: Icons.remove_rounded,
            onTap: onDecrease,
          ),
          Text(
            '$count',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          _SelectorButton(
            icon: Icons.add_rounded,
            onTap: onIncrease,
          ),
        ],
      ),
    );
  }
}

class _SelectorButton extends StatelessWidget {
  const _SelectorButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 34,
          height: 38,
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 18,
          ),
        ),
      ),
    );
  }
}

// ─── EMPTY STATE ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 56, color: AppColors.textMuted),
          SizedBox(height: 16),
          Text(
            'No Items Found',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Try adjusting your search criteria.',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─── CART BANNER ──────────────────────────────────────────────────────────────

/// Blinkit-style slide-up cart summary banner.
///
/// Appears at the bottom of the [MenuScreen] whenever [cart] is non-empty.
/// Shows item count, running total, and a direct "View Cart" shortcut.
class _CartBanner extends StatelessWidget {
  const _CartBanner({
    required this.cart,
    this.onViewCart,
  });

  final Map<String, Map<String, dynamic>> cart;
  final VoidCallback? onViewCart;

  int get _totalItems =>
      cart.values.fold(0, (sum, e) => sum + (e['quantity'] as int? ?? 0));

  int get _totalPrice => cart.values.fold(
        0,
        (sum, e) =>
            sum +
            ((e['price'] as num? ?? 0).toInt() *
                (e['quantity'] as int? ?? 0)),
      );

  @override
  Widget build(BuildContext context) {
    final isVisible = cart.isNotEmpty;

    // Position the banner just above the floating nav pill.
    // Nav pill: ~56 px tall + margin. We use viewPadding.bottom the same
    // way AppBottomNav does so they are always in sync.
    final double systemInset = MediaQuery.viewPaddingOf(context).bottom;
    final double navHeight = 56 + (systemInset > 0 ? systemInset + 8 : 20) + 12;

    return Positioned(
      left: 0,
      right: 0,
      bottom: navHeight,
      child: AnimatedSlide(
        offset: isVisible ? Offset.zero : const Offset(0, 1.5),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Material(
              elevation: 12,
              shadowColor: AppColors.primary.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: onViewCart,
                borderRadius: BorderRadius.circular(20),
                child: Ink(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    child: Row(
                      children: [
                        // ── Cart icon badge ──────────────────────────────────
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            children: [
                              const Center(
                                child: Icon(
                                  Icons.shopping_cart_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              // Item count badge
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  width: 15,
                                  height: 15,
                                  decoration: BoxDecoration(
                                    color: AppColors.terracotta,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$_totalItems',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        // ── Item count + total ───────────────────────────────
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$_totalItems item${_totalItems == 1 ? '' : 's'} in your cart',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₹$_totalPrice',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // ── View Cart button ─────────────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.terracotta,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View Cart',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
