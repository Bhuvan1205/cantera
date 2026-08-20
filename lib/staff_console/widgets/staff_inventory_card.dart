import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// A premium inventory item card for canteen staff.
///
/// - For **non-quantifiable** items (Mess category, Tea, Coffee): shows an
///   availability toggle switch in the same bottom-right position as the
///   stock stepper — since their servings cannot be counted individually.
/// - For all other items: shows the quantity stepper as usual.
class StaffInventoryCard extends StatelessWidget {
  const StaffInventoryCard({
    super.key,
    required this.itemId,
    required this.name,
    required this.stock,
    required this.imageUrl,
    required this.category,
    required this.isAvailable,
    required this.onDecrease,
    required this.onIncrease,
    required this.onToggleAvailability,
  });

  final String itemId;
  final String name;
  final int stock;
  final String imageUrl;
  final String category;
  final bool isAvailable;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final ValueChanged<bool> onToggleAvailability;

  /// Items that use availability toggle instead of a stock counter.
  bool get _isNonQuantifiable {
    final cat = category.toLowerCase();
    final n = name.toLowerCase();
    return cat == 'mess' || cat == 'continental' || n == 'tea' || n == 'coffee';
  }

  @override
  Widget build(BuildContext context) {
    final String status;
    final Color statusColor;

    if (_isNonQuantifiable) {
      status = isAvailable ? 'AVAILABLE' : 'UNAVAILABLE';
      statusColor = isAvailable ? AppColors.success : AppColors.error;
    } else {
      status = _stockStatus(stock);
      if (status == 'CRITICAL') {
        statusColor = AppColors.error;
      } else if (status == 'LOW STOCK') {
        statusColor = AppColors.readyBrown;
      } else {
        statusColor = AppColors.success;
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Curved Item Thumbnail ──
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 76,
              height: 76,
              child: imageUrl.isEmpty
                  ? Container(
                      color: AppColors.imagePlaceholder,
                      child: Icon(
                        Icons.image_not_supported_rounded,
                        size: 24,
                        color: AppColors.primary.withValues(alpha: 0.5),
                      ),
                    )
                  : (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: AppColors.imagePlaceholder,
                            child: const Icon(Icons.broken_image_outlined, size: 24, color: AppColors.textMuted),
                          ),
                        )
                      : Image.asset(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: AppColors.imagePlaceholder,
                            child: const Icon(Icons.broken_image_outlined, size: 24, color: AppColors.textMuted),
                          ),
                        ),
            ),
          ),
          const SizedBox(width: 14),
          // ── Info Grid & Actions ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Row: status badge + category badge ──
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor.withValues(alpha: 0.16), width: 1),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.categoryBadgeBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Item Name
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                // ── Bottom Row: same layout for both modes ──
                // Left side: count/label | Right side: stepper or toggle
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left label column
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _isNonQuantifiable
                          ? [
                              // Small question prompt on the left
                              const Text(
                                'AVAILABLE?',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textMuted,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ]
                          : [
                              Text(
                                stock.toString().padLeft(2, '0'),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                  height: 1.1,
                                ),
                              ),
                              const Text(
                                'UNITS IN STOCK',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textMuted,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                    ),
                    const Spacer(),
                    // Right control: toggle or stepper
                    if (_isNonQuantifiable)
                      _AvailabilityToggle(
                        isAvailable: isAvailable,
                        onChanged: onToggleAvailability,
                      )
                    else
                      _StepperControl(
                        value: stock,
                        onDecrease: onDecrease,
                        onIncrease: onIncrease,
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

  String _stockStatus(int stock) {
    if (stock <= 5) return 'CRITICAL';
    if (stock <= 15) return 'LOW STOCK';
    return 'STABLE';
  }
}

// ─── AVAILABILITY TOGGLE (for non-quantifiable items) ────────────────────────

class _AvailabilityToggle extends StatelessWidget {
  const _AvailabilityToggle({
    required this.isAvailable,
    required this.onChanged,
  });

  final bool isAvailable;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // "No" label
        Text(
          'No',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isAvailable ? AppColors.textMuted : AppColors.error,
          ),
        ),
        const SizedBox(width: 4),
        Transform.scale(
          scale: 0.85,
          child: Switch(
            value: isAvailable,
            onChanged: onChanged,
            activeThumbColor: AppColors.success,
            activeTrackColor: AppColors.success.withValues(alpha: 0.25),
            inactiveThumbColor: AppColors.error,
            inactiveTrackColor: AppColors.error.withValues(alpha: 0.18),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 4),
        // "Yes" label
        Text(
          'Yes',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isAvailable ? AppColors.success : AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

// ─── STEPPER CONTROL ─────────────────────────────────────────────────────────

class _StepperControl extends StatelessWidget {
  const _StepperControl({
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int value;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.summaryCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove_rounded,
            onTap: value > 0 ? onDecrease : null,
          ),
          SizedBox(
            width: 38,
            child: Center(
              child: Text(
                '$value',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            onTap: onIncrease,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;

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
            color: isDisabled ? Colors.grey.shade400 : AppColors.primary,
            size: 18,
          ),
        ),
      ),
    );
  }
}
