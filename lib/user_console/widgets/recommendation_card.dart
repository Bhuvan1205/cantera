import 'package:flutter/material.dart';


class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    super.key,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.onAddTap,
  });

  final String name;
  final int price;
  final String imageUrl;
  final String category;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Small food-related image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 48,
              height: 48,
              color: const Color(0xFFE8F5E9), // Light green background
              child: _buildImage(),
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B5E20), // Dark green text
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹$price',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2E7D32), // Dark green price
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onAddTap,
                        borderRadius: BorderRadius.circular(8),
                        child: Ink(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.add_rounded,
                              color: Color(0xFF2E7D32),
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (imageUrl.isEmpty) {
      return const Icon(
        Icons.restaurant_menu_rounded,
        color: Color(0xFF2E7D32),
        size: 24,
      );
    }
    
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF2E7D32),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.broken_image_outlined,
          size: 24,
          color: Color(0xFF2E7D32),
        ),
      );
    }
    
    return Image.asset(
      imageUrl,
      fit: BoxFit.cover,
      cacheWidth: 100,
      cacheHeight: 100,
      errorBuilder: (context, error, stackTrace) => const Icon(
        Icons.broken_image_outlined,
        size: 24,
        color: Color(0xFF2E7D32),
      ),
    );
  }
}
