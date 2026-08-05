import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/services/api_client.dart';
import '../../theme/app_colors.dart';
import '../widgets/staff_inventory_card.dart';

/// The inventory tab of the Canteen Staff Terminal.
///
/// Features low stock warnings, total units tracked summary boxes, and
/// individual item steppers to dynamically update item counts in real time.
///
/// **Mess category items** use an `isAvailable` boolean toggle instead of a
/// stock stepper — mess servings cannot be counted individually.
class StaffInventoryTab extends StatelessWidget {
  const StaffInventoryTab({super.key});

  Future<void> _updateStock(String itemId, int delta) async {
    try {
      // Read current stock from Firestore snapshot then patch via backend
      final docRef = FirebaseFirestore.instance.collection('Menu').doc(itemId);
      final snap = await docRef.get();
      if (!snap.exists) return;
      final currentStock = ((snap.data()?['stock'] ?? 0) as num).toInt();
      final nextStock = (currentStock + delta).clamp(0, 9999);
      await ApiClient.instance.patch('/api/inventory/$itemId', body: {
        'stock': nextStock,
      });
    } catch (e) {
      debugPrint('Error updating stock for $itemId: $e');
    }
  }

  Future<void> _toggleAvailability(String itemId, bool newValue) async {
    try {
      await ApiClient.instance.patch('/api/inventory/$itemId', body: {
        'is_available': newValue,
      });
    } catch (e) {
      debugPrint('Error toggling availability for $itemId: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('Menu').snapshots(),

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        // Only quantifiable items have meaningful stock counts.
        // Mess category, Continental category, Tea, and Coffee use availability toggle — exclude from totals.
        final nonQuantifiableDocs = docs.where((doc) {
          final cat = (doc.data()['category'] as String? ?? '').toLowerCase();
          final itemName = (doc.data()['name'] as String? ?? '').trim().toLowerCase();
          return cat != 'mess' && cat != 'continental' && itemName != 'tea' && itemName != 'coffee';
        }).toList();

        final totalUnits = nonQuantifiableDocs.fold<int>(
          0,
          (previousValue, doc) => previousValue + ((doc.data()['stock'] ?? 0) as num).toInt(),
        );
        final lowStockCount = nonQuantifiableDocs.where((doc) {
          final stock = ((doc.data()['stock'] ?? 0) as num).toInt();
          return stock <= 15;
        }).length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 110), // Padding to clear bottom nav
          children: [
            // Top Section Indicator
            const Text(
              'MANAGEMENT HUB',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 8),
            // Header Title
            const Text(
              'Live Inventory\nControl',
              style: TextStyle(
                height: 1.05,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 14),
            // Summary Info cards side-by-side
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _InventorySummaryCard(
                      title: 'LOW STOCK\nITEMS',
                      value: lowStockCount.toString().padLeft(2, '0'),
                      icon: Icons.warning_amber_rounded,
                      backgroundColor: AppColors.errorBg,
                      textColor: AppColors.error,
                      borderColor: AppColors.errorBorder,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InventorySummaryCard(
                      title: 'TOTAL UNITS\nTRACKED',
                      value: '$totalUnits',
                      icon: Icons.insert_chart_outlined_rounded,
                      backgroundColor: AppColors.summaryCard,
                      textColor: AppColors.primary,
                      borderColor: AppColors.border,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Subtitle Listing
            const Text(
              'Menu Stock Levels',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            // List of Inventory Items
            ...docs.map((doc) {
              final data = doc.data();
              final stock = ((data['stock'] ?? 0) as num).toInt();
              final category = data['category'] as String? ?? 'Kitchen';
              final isAvailable = (data['isAvailable'] ?? true) as bool;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: StaffInventoryCard(
                  itemId: doc.id,
                  name: _titleCase(data['name'] as String? ?? 'Unknown'),
                  stock: stock,
                  imageUrl: _resolveImageUrl(
                    data['name'] as String? ?? '',
                    data['imageUrl'] as String? ?? '',
                  ),
                  category: category,
                  isAvailable: isAvailable,
                  onDecrease: () => _updateStock(doc.id, -1),
                  onIncrease: () => _updateStock(doc.id, 1),
                  onToggleAvailability: (newValue) =>
                      _toggleAvailability(doc.id, newValue),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  String _resolveImageUrl(String rawName, String firestoreImageUrl) {
    final normalized = rawName.trim().toLowerCase();

    const curatedImages = <String, String>{
      'veg puff': 'Menu item pictures/veg puff.jpeg',
      'egg puff': 'Menu item pictures/egg puff.jpeg',
      'chicken puff': 'Menu item pictures/egg puff.jpeg', // fallback
      'samosa': 'Menu item pictures/samosa.jpeg',
      'idli': 'Menu item pictures/idli.jpeg',
      'dosa': 'Menu item pictures/dosa.jpeg',
      'tea': 'Menu item pictures/tea.jpeg',
      'coffee': 'Menu item pictures/coffee.jpeg',
      'thumbs up': 'Menu item pictures/thumbsup.jpeg',
      'cold drink': 'Menu item pictures/thumbsup.jpeg', // fallback
      'meals': 'Menu item pictures/meals.jpeg',
    };

    final curated = curatedImages[normalized];
    if (curated != null) {
      return curated;
    }

    return firestoreImageUrl;
  }

  String _titleCase(String value) {
    return value.split(' ').map((word) {
      if (word.isEmpty) return word;
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }
}

class _InventorySummaryCard extends StatelessWidget {
  const _InventorySummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: textColor,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
